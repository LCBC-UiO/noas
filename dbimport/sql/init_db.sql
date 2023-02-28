/*
 * After running this file, non_core data should be added to the DB with:
 * 
 * import_table(input_table_name, noas_table_id, noas_json, noas_data_source)
 * import_metadata(noas_table_id, metadata_json)
 * 
 * where:
 *   input_table_name - the name of an already existing (temporary) 
 *                        where the data will be taken from
 *   noas_table_id    - the id of the tabe in noas (without the noas_ prefix).
 *                        The table will be created automatically.
 *   noas_json        - the json containing the table_type and in some cases 
                          the repeated group (contents of _noas.json)
 *   metadata_json    - the json containing the metadata (contents of _metadata.json)
 * 
 *
 */

-- suppress NOTICE messages
SET client_min_messages = warning;

-- Delete everything in the database

DROP VIEW IF EXISTS noas_core;
-- drop tables if they exist
-- creates a script to delete all long_* tables
DO
$do$
DECLARE
  _tbl text;
BEGIN
FOR _tbl  IN
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = 'public'
LOOP
  EXECUTE 'DROP TABLE IF EXISTS ' || _tbl || ' CASCADE';
END LOOP;
END
$do$;
DROP TYPE IF EXISTS e_sex CASCADE;
DROP TYPE IF EXISTS e_sampletype CASCADE;
DROP TYPE IF EXISTS e_columntype CASCADE;


DO
$do$
DECLARE
   _idx text;
BEGIN
FOR _idx  IN
  SELECT indexname
  FROM pg_indexes
  WHERE schemaname = 'public'
LOOP
  EXECUTE 'DROP INDEX ' || _idx;
END LOOP;
END
$do$;

--------------------------------------------------------------------------------

-- Define Types

CREATE TYPE e_sex AS enum (
  'Female'
  ,'Male'
);

CREATE TYPE e_sampletype AS enum (
  'core'
  ,'cross'
  ,'long'
  ,'repeated'
);

CREATE TYPE e_columntype AS enum (
  'text'
  ,'float'
  ,'integer'
  ,'date'
  ,'time'
  ,'boolean'
);

--------------------------------------------------------------------------------

-- Define functions

-- Count number of rows for a table by project similar to "count(*)"
CREATE OR REPLACE FUNCTION row_count (metatable_sampletype e_sampletype, metatable_id text, project_id text)
RETURNS integer AS $total$
DECLARE
	total integer;
BEGIN
  if ( project_id = 'all' ) then
    EXECUTE format(
      $ex$
        select count(*) from %I t 
          where t.subject_id in 
          ( select c.subject_id from noas_core c where c.subject_shareable = B'1' )
      $ex$, 'noas' || '_' || metatable_id
    ) INTO total;
  else
    if ( metatable_sampletype = 'long' or metatable_sampletype = 'repeated' or metatable_sampletype = 'core' ) then
      EXECUTE format(
        $ex$
          select count(*) from %I t 
            where t.project_id = '%s'
        $ex$, 'noas' || '_' || metatable_id, project_id
      ) INTO total;
    else -- this is for cross-sectional data:
      EXECUTE format(
        $ex$
          select count(*) from %I t
            where t.subject_id in 
            ( select c.subject_id from noas_core c where c.project_id = '%s' )
        $ex$, 'noas' || '_' || metatable_id, project_id
      ) INTO total;
    end if;
  end if;
  RETURN total;
END;
$total$ LANGUAGE plpgsql;

-- get duration in years - used for age at visit
CREATE OR REPLACE FUNCTION age_to_decimal_years(age INTERVAL)
RETURNS NUMERIC AS $$
BEGIN
    RETURN (EXTRACT(YEAR FROM age) + EXTRACT(MONTH FROM age) / 12.0 + EXTRACT(DAY FROM age) / 365.25);
END;
$$ LANGUAGE plpgsql;

-- add column "noas data source"
CREATE OR REPLACE FUNCTION _add_noas_ds_col(table_name_in regclass, noas_data_source text)
RETURNS void AS $$
BEGIN
  -- add noas_data_source
  EXECUTE format(
    $ex$
      ALTER TABLE %s ADD COLUMN _noas_data_source text;
    $ex$
    ,table_name_in
  );
  EXECUTE format(
    $ex$
      UPDATE %s SET _noas_data_source = '%s';
    $ex$
    ,table_name_in
    ,noas_data_source
  );
END;
$$ LANGUAGE plpgsql;

-- create auto generated metadata
CREATE OR REPLACE FUNCTION _write_default_metadata(table_name_dst text, sample_type e_sampletype, _4th_col_id TEXT DEFAULT NULL)
RETURNS void AS $$
DECLARE
	_colid text;
  _col_counter int := 1;
BEGIN
  EXECUTE format(
    $ex$
      INSERT INTO metatables (id, sampletype, title)
        VALUES ('%s', '%s', INITCAP('%s'))
        ON conflict (id) do nothing;
    $ex$
    ,table_name_dst
    ,sample_type
    ,table_name_dst
  );
  IF _4th_col_id IS NOT NULL THEN
    EXECUTE format(
      $ex$
        INSERT INTO metacolumns (metatable_id, id, idx, title) 
          VALUES ('%s', '%s', '%s', '%s')
          ON CONFLICT DO NOTHING;
      $ex$
      ,table_name_dst
      ,_4th_col_id
      ,_col_counter
      ,_4th_col_id
    );
    SELECT _col_counter + 1 INTO _col_counter;
  END IF;
  FOR _colid IN
    SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name   = 'noas_' || table_name_dst
        AND column_name  like '\_%'
  LOOP
    EXECUTE format(
      $ex$
        INSERT INTO metacolumns (metatable_id, id, idx, title) 
          VALUES ('%s', '%s', '%s', INITCAP(REPLACE(SUBSTRING('%s', 2), '_', ' ')))
          ON CONFLICT DO NOTHING;
      $ex$
      ,table_name_dst
      ,_colid
      ,_col_counter
      ,_colid
    );
    SELECT _col_counter + 1 INTO _col_counter;
  END LOOP;
  -- fix metadata
  EXECUTE format(
    $ex$
      UPDATE metacolumns 
        SET idx = 9999, descr = 'File in the NOAS data directory where the information comes from'
        WHERE metatable_id = '%s' AND id = '_noas_data_source';
    $ex$
    ,table_name_dst
  );
END;
$$ LANGUAGE plpgsql;

-- import cross
CREATE OR REPLACE FUNCTION _import_cross_table(table_name_in regclass, table_name_dst text, noas_data_source text)
RETURNS void AS $$
DECLARE
  _colid text;
  visit_id_colname text;
  _s integer;
BEGIN
  EXECUTE format(
    $ex$
      ALTER TABLE %s
        ALTER column subject_id TYPE int USING subject_id::integer;    
    $ex$
    ,table_name_in
  );
  -- prefix non-pk columns with _
  FOR _colid IN
    SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name   = table_name_in::text
        AND column_name NOT IN ('subject_id')
  LOOP
    EXECUTE format(
      $ex$
        ALTER TABLE %s
          RENAME COLUMN "%s" TO _%s;
      $ex$
      ,table_name_in
      ,_colid
      ,_colid
    );
  END LOOP;
  -- check if defined 
  FOR _s IN EXECUTE format(
    $ex$
      SELECT subject_id FROM %s t
      WHERE t.subject_id NOT IN (SELECT subject_id FROM visits)
    $ex$
    ,table_name_in
  )
  LOOP
    RAISE warning 'missing core data (subject_id=%) in file %', _s, noas_data_source;
  END LOOP;
  PERFORM _add_noas_ds_col(table_name_in, noas_data_source);
  EXECUTE format(
    $ex$
      CREATE TABLE IF NOT EXISTS noas_%s (
        LIKE %s including ALL,
        CONSTRAINT noas_%s_pk PRIMARY KEY (subject_id),
        CONSTRAINT noas_%s_fk FOREIGN KEY (subject_id) REFERENCES subjects(id)
      )
    $ex$
    ,table_name_dst
    ,table_name_in
    ,table_name_dst
    ,table_name_dst
  );
  EXECUTE format(
    $ex$
      INSERT INTO noas_%s
        SELECT * FROM %s t
        WHERE (t.subject_id) IN (SELECT id FROM subjects);
    $ex$
    ,table_name_dst
    ,table_name_in
  );
  -- auto create metadata
  PERFORM _write_default_metadata(table_name_dst, 'cross');
END;
$$ LANGUAGE plpgsql;

-- import long
CREATE OR REPLACE FUNCTION _import_long_table(table_name_in regclass, table_name_dst text, noas_data_source text)
RETURNS void AS $$
DECLARE
  _colid text;
  visit_id_colname text;
  _s integer;
  _p text;
  _w float;
BEGIN
  EXECUTE format(
    $ex$
      ALTER TABLE %s
        ALTER column subject_id TYPE int USING subject_id::integer,
        ALTER column project_id TYPE text,
        ALTER column wave_code TYPE numeric(3,1) USING wave_code::numeric(3,1);
    $ex$
    ,table_name_in
  );
  -- prefix non-pk columns with _
  FOR _colid IN
    SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name   = table_name_in::text
        AND column_name NOT IN ('subject_id', 'project_id', 'wave_code')
  LOOP
    EXECUTE format(
      $ex$
        ALTER TABLE %s
          RENAME COLUMN "%s" TO _%s;
      $ex$
      ,table_name_in
      ,_colid
      ,_colid
    );
  END LOOP;
  -- check if defined 
  FOR _s, _p, _w IN EXECUTE format(
    $ex$
      SELECT subject_id, project_id, wave_code FROM %s t
      WHERE (t.subject_id, t.project_id, t.wave_code) NOT IN (SELECT subject_id, project_id, wave_code FROM visits)
    $ex$
    ,table_name_in
  )
  LOOP
    RAISE warning 'missing core data (subject_id=%, project_id=%, wave_code=%) in file %', _s, _p, _w, noas_data_source;
  END LOOP;
  PERFORM _add_noas_ds_col(table_name_in, noas_data_source);
  EXECUTE format(
    $ex$
      CREATE TABLE IF NOT EXISTS noas_%s (
        LIKE %s including ALL,
        CONSTRAINT noas_%s_pk PRIMARY KEY (subject_id, project_id, wave_code),
        CONSTRAINT noas_%s_fk FOREIGN KEY (subject_id, project_id, wave_code) REFERENCES visits(subject_id, project_id, wave_code)
      )
    $ex$
    ,table_name_dst
    ,table_name_in
    ,table_name_dst
    ,table_name_dst
  );
  EXECUTE format(
    $ex$
      INSERT INTO noas_%s
        SELECT * FROM %s t
        WHERE (t.subject_id, t.project_id, t.wave_code) IN (SELECT subject_id, project_id, wave_code FROM visits);
    $ex$
    ,table_name_dst
    ,table_name_in
  );
  -- auto create metadata
  PERFORM _write_default_metadata(table_name_dst, 'long');
END;
$$ LANGUAGE plpgsql;

-- get column id of nth column
CREATE OR REPLACE FUNCTION _get_nth_colname(tab_name text, col_id int)
RETURNS text AS $$
BEGIN
  RETURN(
    SELECT column_name 
      FROM information_schema.columns
      WHERE table_schema = 'public'
      AND table_name   = tab_name
      AND ordinal_position = col_id
  );
END;
$$ LANGUAGE plpgsql;

-- import repeated
CREATE OR REPLACE FUNCTION _import_repeated_table(table_name_in regclass, table_name_dst text, noas_data_source text, repeated_grp text)
RETURNS void AS $$
DECLARE
  _colid text;
  _4th_col_id text;
  _s integer;
  _p text;
  _w float;
BEGIN
  EXECUTE format(
    $ex$
      ALTER TABLE %s
        ALTER column subject_id TYPE int USING subject_id::integer,
        ALTER column project_id TYPE text,
        ALTER column wave_code TYPE numeric(3,1) USING wave_code::numeric(3,1);
    $ex$
    ,table_name_in
  );
  SELECT _get_nth_colname(table_name_in::text, 4) INTO _4th_col_id;
  -- prefix non-pk columns with _
  FOR _colid IN
      SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = table_name_in::text
          AND column_name NOT IN ('subject_id', 'project_id', 'wave_code', _4th_col_id)
    LOOP
      EXECUTE format(
        $ex$
          ALTER TABLE %s
            RENAME COLUMN "%s" TO _%s;
        $ex$
        ,table_name_in
        ,_colid
        ,_colid
      );
    END LOOP;
  -- check if defined 
  FOR _s, _p, _w IN EXECUTE format(
    $ex$
      SELECT subject_id, project_id, wave_code FROM %s t
      WHERE (t.subject_id, t.project_id, t.wave_code) NOT IN (SELECT subject_id, project_id, wave_code FROM visits)
    $ex$
    ,table_name_in
  )
  LOOP
    RAISE warning 'missing core data (subject_id=%, project_id=%, wave_code=%) in file %', _s, _p, _w, noas_data_source;
  END LOOP;
  PERFORM _add_noas_ds_col(table_name_in, noas_data_source);
  EXECUTE '
    CREATE TABLE IF NOT EXISTS noas_' || table_name_dst || ' (
      LIKE ' || table_name_in || ' including ALL,
      CONSTRAINT noas_' || table_name_dst || '_pk PRIMARY KEY (subject_id, project_id, wave_code, ' ||  _4th_col_id || '),
      CONSTRAINT noas_' || table_name_dst || '_fk FOREIGN KEY (subject_id, project_id, wave_code) REFERENCES visits(subject_id, project_id, wave_code))
   ';
  EXECUTE format(
    $ex$
      INSERT INTO noas_%s
        SELECT * FROM %s t
        WHERE (t.subject_id, t.project_id, t.wave_code) IN (SELECT subject_id, project_id, wave_code FROM visits);
    $ex$
    ,table_name_dst
    ,table_name_in
  );
  -- auto create metadata
  PERFORM _write_default_metadata(table_name_dst, 'repeated', _4th_col_id);
  -- add repeated group?
  IF repeated_grp IS NOT NULL THEN
    INSERT INTO meta_repeated_grps (metatable_id, metacolumn_id, repeated_group) 
      VALUES (table_name_dst, _4th_col_id, repeated_grp);
  END IF;
END;

$$ LANGUAGE plpgsql;

-- import table
CREATE OR REPLACE FUNCTION import_table(table_name_in regclass, noas_table_id text, noas_json json, noas_data_source text)
RETURNS boolean AS $$
DECLARE
   _table_type e_sampletype;
BEGIN
  IF noas_json->>'table_type' IS NULL THEN
    RAISE EXCEPTION 'noas_json is missing column "table_type" field';
  ELSIF noas_json->>'table_type' = 'cross-sectional' THEN
    SELECT 'cross' into _table_type;
  ELSIF noas_json->>'table_type' = 'longitudinal' THEN
    SELECT 'long' into _table_type;
  ELSIF noas_json->>'table_type' = 'repeated' THEN
    SELECT 'repeated' into _table_type;
  END IF;
  IF noas_json->>'table_type' = 'repeated' THEN
    PERFORM _import_repeated_table(table_name_in, noas_table_id, noas_data_source, noas_json->>'repeated_group');
  ELSE
    EXECUTE format(
      $ex$
        SELECT _import_%s_table('%s', '%s', '%s'); --this is not happy with PERFORM instead. Maybe becaue within EXECUTE format?
      $ex$
      ,_table_type
      ,table_name_in
      ,noas_table_id
      ,noas_data_source
    );
  END IF;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- import a column from metadata json
CREATE OR REPLACE FUNCTION _import_col_metadata(table_id text, col_metadata json)
RETURNS void AS $$
DECLARE
   _key   text;
   _value json;
BEGIN
  IF col_metadata->>'id' IS NULL THEN
    RAISE EXCEPTION 'Metadata is missing column ID field';
  END IF;
  FOR _key, _value IN SELECT * FROM json_each(col_metadata)
  LOOP
    IF _key = ANY (ARRAY['descr','type']) THEN
      EXECUTE format(
        $ex$
          UPDATE metacolumns SET %s = %s WHERE metatable_id = '%s' AND id = '_%s';
        $ex$
        ,_key
        ,quote_literal(_value #>> '{}')
        ,table_id
        ,col_metadata->>'id'
      );
    ELSIF _key = 'id' THEN
      -- do nothing
    ELSE
      RAISE EXCEPTION 'Unknown metadata column field "%"', _key; 
    END IF;
    IF _key = 'type' THEN
      IF _value #>> '{}' = ANY (ARRAY['float','integer','date','time']) THEN -- might need to translate type at some point
        EXECUTE format(
          $ex$
            ALTER TABLE noas_%s ALTER COLUMN _%s TYPE %s USING (_%s::%s);
          $ex$
          ,table_id
          ,col_metadata->>'id'
          ,_value #>> '{}'
          ,col_metadata->>'id'
          ,_value #>> '{}'
        );
      ELSIF _value #>> '{}' = 'boolean' THEN
        EXECUTE format(
          $ex$
            ALTER TABLE noas_%s ALTER COLUMN _%s TYPE bit(1) USING (_%s::bit(1));
          $ex$
          ,table_id
          ,col_metadata->>'id'
          ,col_metadata->>'id'
        );
      ELSIF _value #>> '{}' = 'text' THEN
        -- do nothing - it's already ::text
      ELSE
        RAISE EXCEPTION 'Unknown column type "%"', _value #>> '{}';
      END IF;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- import metadata
CREATE OR REPLACE FUNCTION import_metadata(table_id text, metadata json)
RETURNS boolean AS $$
DECLARE
   _key   text;
   _value json;
   _col   json;
   _cats  json[];
BEGIN
    FOR _key, _value IN
       SELECT * FROM json_each(metadata)
    LOOP
      IF _key = ANY (ARRAY['title','descr']) THEN
        EXECUTE format(
          $ex$
            UPDATE metatables SET %s = %s WHERE id = '%s';
          $ex$
          ,_key
          ,quote_literal(_value #>> '{}')
          ,table_id
        );
      ELSIF _key = 'category' THEN
        SELECT array(SELECT json_array_elements(_value)) INTO _cats;
        UPDATE metatables 
          SET category = (SELECT array(SELECT json_array_elements_text(_value)))
          WHERE id = table_id;
      ELSIF _key = 'columns' THEN
        FOR _col IN SELECT * FROM json_array_elements(_value)
        LOOP
          PERFORM _import_col_metadata(table_id, _col);
        END LOOP;
      ELSE
        RAISE EXCEPTION 'Unknown metadata field "%"', _key;
      END IF;
    END LOOP;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------

-- Create project table

CREATE TABLE projects (
  id text NOT NULL,
  code int NOT NULL,
  name text NULL,
  description text NULL,
  CONSTRAINT project_pkey PRIMARY KEY (id)
);

-- Create wave table

CREATE TABLE waves (
  code float NOT NULL,
  project_id text NOT NULL,
  reknr int NULL,
  description text NULL,
  CONSTRAINT wave_pkey PRIMARY KEY (code, project_id),
  CONSTRAINT wave_project_fk FOREIGN KEY (project_id) REFERENCES projects(id)
);


-- Create subject table

CREATE TABLE subjects (
  id int NOT NULL,
  birthdate date NULL,
  sex e_sex NULL,
  shareable bit(1) NULL,
  CONSTRAINT subject_pk PRIMARY KEY (id)
);
CREATE INDEX subjects_idx_shr ON subjects (shareable);


-- Create visit table

CREATE TABLE visits (
  subject_id int NOT NULL,
  project_id text,
  wave_code float,
  alt_subj_id text,
  "date"  date,
  CONSTRAINT visit_pk PRIMARY KEY(subject_id, wave_code, project_id),
  CONSTRAINT visit_subject_fk FOREIGN KEY (subject_id) REFERENCES subjects(id),
  CONSTRAINT visit_wave_fk FOREIGN KEY (wave_code, project_id) REFERENCES waves(code, project_id)
);

--------------------------------------------------------------------------------

-- metadata for tables

CREATE TABLE metatables (
  id text,
  sampletype e_sampletype,
  category   text[] DEFAULT ARRAY[]::text[],
  idx        integer DEFAULT 1,
  title      text,
  descr text DEFAULT NULL,
  CONSTRAINT metatables_pk PRIMARY KEY(id)
);

-- metadata for table columns

CREATE TABLE metacolumns (
  metatable_id text,
  id    text,
  idx   integer DEFAULT 1,
  title text,
  descr text DEFAULT NULL,
  type  e_columntype,
  CONSTRAINT metacolumns_pk PRIMARY KEY (metatable_id, id),
  CONSTRAINT metacolumns_fk FOREIGN KEY (metatable_id) REFERENCES metatables(id)
);

-- metadata how to merge repeated tables

CREATE TABLE meta_repeated_grps (
  metatable_id text,
  metacolumn_id text,
  repeated_group text NOT NULL,
  CONSTRAINT meta_repeated_grps_pk PRIMARY KEY (metatable_id),
  CONSTRAINT meta_repeated_grps_table_fk FOREIGN KEY (metatable_id) REFERENCES metatables(id),
  CONSTRAINT meta_repeated_grps_col_fk   FOREIGN KEY (metatable_id, metacolumn_id) REFERENCES metacolumns(metatable_id, id)
);

-- metadata for data version

CREATE TABLE versions (
  id               text,
  label            text,
  ts               timestamp,
  import_completed bool DEFAULT false,
  CONSTRAINT versions_pkey PRIMARY KEY (id)
);

--------------------------------------------------------------------------------

-- Combine core tables

CREATE VIEW noas_core AS
  SELECT
    v.subject_id,
    s.birthdate AS subject_birthdate,
    s.sex AS subject_sex,
    s.shareable AS subject_shareable,
    v.alt_subj_id AS visit_alt_subj_id,
    v.date AS visit_date,
    v.number AS visit_number,
    (v.interval_bl/ 60 / 60 / 24 / 365.25) AS visit_interval_bl,
    w.reknr AS wave_reknr,
    w.description AS wave_description,
    w.code AS wave_code,
    p.id AS project_id,
    p.name AS project_name,
    p.code AS project_code,
    p.description AS project_description,
    age_to_decimal_years(age(v.date, s.birthdate)) AS visit_age
  FROM (
    SELECT 
      subject_id, 
      project_id, 
      wave_code,
      alt_subj_id,
      date,
      ROW_NUMBER() OVER (PARTITION BY subject_id ORDER BY date) AS number,
      EXTRACT(EPOCH FROM (date::timestamp - LAG(date::timestamp) OVER (PARTITION BY subject_id ORDER BY date))) AS interval_bl
    FROM visits
  ) AS v
  LEFT JOIN waves AS w ON v.wave_code = w.code AND v.project_id = w.project_id
  LEFT JOIN subjects AS s ON v.subject_id = s.id
  LEFT JOIN projects AS p ON v.project_id = p.id;


-- Add metadata for core table

INSERT INTO metatables (id, sampletype, idx, title) VALUES ('core', 'core', 0, 'Core data');
UPDATE metatables SET descr = 'Basic data for any participant' where id = 'core';

INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'subject_id',           0, 'integer', 'Subject ID');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'project_id',           1, 'text',    'Project ID');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'wave_code',            2, 'float',   'Wave code');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'subject_sex',          3, 'text',    'Sex');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'subject_birthdate',    4, 'date',    'Birth date');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'subject_shareable',    5, 'boolean', 'Shareable');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'visit_alt_subj_id',    6, 'text',    'Alternate Subject ID');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'visit_date',           7, 'date',    'Visit date');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'visit_age',            8, 'float',   'Age at visit');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'visit_number',         9, 'integer', 'Visit number');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'visit_interval_bl',   10, 'float',   'Interval from baseline');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'project_name',        11, 'text',    'Project name');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'project_code',        12, 'integer', 'Project code');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'project_description', 13, 'text',    'Project description');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'wave_description',    14, 'text',    'Wave description');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'wave_reknr',          15, 'integer', 'Wave REK Nr.');

UPDATE metacolumns SET descr = '(visit_date - subject_birthdate); #Y+(#M*365/12+#D)/365' where id = 'visit_age';
UPDATE metacolumns SET descr = 'Subject id at the time of data collection for older projects with different ID systems than now, and participants that have joined several projects under different IDs.' where id = 'visit_alt_subj_id';
UPDATE metacolumns SET descr = 'Date of cognitive testing. If this is missing, MRI date. If both these are missing, an approximate date is calculated using birthdate and age recorded at testing (old data).' where id = 'visit_date';
UPDATE metacolumns SET descr = 'Sequential counter of visits. Increases by one for each time a subject is assessed for a project wave of data collection.' where id = 'visit_number';
UPDATE metacolumns SET descr = 'Interval from baseline in decimal years' where id = 'visit_interval_bl';
