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
  ,'timestamp'
  ,'boolean'
);

-- Functions


--- Count number of rows for a table by project similar to "count(*)"
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
  -- add repeated group
  IF repeated_grp IS NOT NULL THEN
    INSERT INTO meta_repeated_grps (metatable_id, metacolumn_id, repeated_group) 
      VALUES (table_name_dst, _4th_col_id, repeated_grp)
    ON CONFLICT DO NOTHING; -- Ignore duplicate key violation
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
   col_id text;

BEGIN
  IF col_metadata->>'id' IS NULL THEN
    RAISE EXCEPTION 'Metadata is missing column ID field';
  END IF;

  -- assign col_id with underscore prefix if column does not exist in table
  col_id := col_metadata->>'id'; -- assign col_metadata->>'id' to a variable 'col_id'
  col_id := CASE
              WHEN EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='noas_' || table_id AND column_name=col_id::text)
              THEN col_id
              ELSE '_' || col_id
            END;
  
  FOR _key, _value IN SELECT * FROM json_each(col_metadata)
  LOOP
    IF _key = ANY (ARRAY['descr','type']) THEN
      EXECUTE format(
        $ex$
          UPDATE metacolumns SET %s = %s WHERE metatable_id = '%s' AND id = '%s';
        $ex$
        ,_key
        ,quote_literal(_value #>> '{}')
        ,table_id
        ,col_id
      );
    ELSIF _key = 'id' THEN
      -- do nothing
    ELSE
      RAISE EXCEPTION 'Unknown metadata column field "%"', _key; 
    END IF;
    IF _key = 'type' THEN
      IF _value #>> '{}' = ANY (ARRAY['float','integer','date','time','timestamp']) THEN -- might need to translate type at some point
        EXECUTE format(
          $ex$
            ALTER TABLE noas_%s ALTER COLUMN %s TYPE %s USING (%s::%s);
          $ex$
          ,table_id
          ,col_id
          ,_value #>> '{}'
          ,col_id
          ,_value #>> '{}'
        );
      ELSIF _value #>> '{}' = 'boolean' THEN
        EXECUTE format(
          $ex$
            ALTER TABLE noas_%s ALTER COLUMN %s TYPE bit(1) USING (%s::bit(1));
          $ex$
          ,table_id
          ,col_id
          ,col_id
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


-- Create trigger function to validate visit date against subject birthdate
CREATE FUNCTION validate_visit_date() RETURNS TRIGGER AS $$
BEGIN
  IF NEW."date" = (SELECT birthdate FROM subjects WHERE id = NEW.subject_id) THEN
    RAISE EXCEPTION 'Visit date cannot be the same as subject birthdate';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Create trigger function to validate visit age
CREATE FUNCTION validate_visit_age() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.age < 3 THEN
    RAISE EXCEPTION 'Visit age cannot be less than 3';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


