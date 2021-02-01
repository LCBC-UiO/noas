-- suppress NOTICE messages
SET client_min_messages = warning;

-- Delete everything in the database

DROP VIEW IF EXISTS core_core;
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
          ( select c.subject_id from core_core c where c.subject_shareable = 1 )
      $ex$, metatable_sampletype || '_' || metatable_id
    ) INTO total;
  else
    if ( metatable_sampletype = 'long' or metatable_sampletype = 'repeated' or metatable_sampletype = 'core' ) then
      EXECUTE format(
        $ex$
          select count(*) from %I t 
            where t.project_id = '%s'
        $ex$, metatable_sampletype || '_' || metatable_id, project_id
      ) INTO total;
    else -- this is for cross-sectional data:
      EXECUTE format(
        $ex$
          select count(*) from %I t
            where t.subject_id in 
            ( select c.subject_id from core_core c where c.project_id = '%s' )
        $ex$, metatable_sampletype || '_' || metatable_id, project_id
      ) INTO total;
    end if;
  end if;
  RETURN total;
END;
$total$ LANGUAGE plpgsql;

-- get duration in years - used for age at visit
CREATE OR REPLACE FUNCTION decimal_years (d interval)
RETURNS float AS $yrs$
DECLARE
	yrs float;
BEGIN
  SELECT ROUND((
      date_part('years', d)::float + (
        date_part('month', d)::float * (365::float/12) +
        date_part('day', d)
      ) / 365
    )::numeric
    , 2
  ) INTO yrs;
  RETURN yrs;
END;
$yrs$ LANGUAGE plpgsql;


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
  shareable int NULL,
  CONSTRAINT subject_pk PRIMARY KEY (id)
);
CREATE INDEX subjects_idx_shr ON subjects (shareable);


-- Create visit table

CREATE TABLE visits (
  subject_id int NOT NULL,
  project_id text,
  wave_code float,
  visitdate date,
  CONSTRAINT visit_pk PRIMARY KEY(subject_id, wave_code, project_id),
  CONSTRAINT visit_subject_fk FOREIGN KEY (subject_id) REFERENCES subjects(id),
  CONSTRAINT visit_wave_fk FOREIGN KEY (wave_code, project_id) REFERENCES waves(code, project_id)
);

--------------------------------------------------------------------------------

-- metadata for tables

CREATE TABLE metatables (
  id text,
  sampletype e_sampletype,
  category   text,
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
  CONSTRAINT metacolumns_pk PRIMARY KEY (metatable_id, id),
  CONSTRAINT metacolumns_fk FOREIGN KEY (metatable_id) REFERENCES metatables(id)
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

CREATE VIEW core_core AS
  SELECT
    subjects.id        AS subject_id,
    subjects.birthdate AS subject_birthdate,
    subjects.sex       AS subject_sex,
    subjects.shareable AS subject_shareable,
    visits.visitdate   AS visit_visitdate,
    waves.reknr        AS wave_reknr,
    waves.description  AS wave_description,
    waves.code         AS wave_code,
    projects.id          AS project_id,
    projects.name        AS project_name,
    projects.code        AS project_code,
    projects.description AS project_description,
    decimal_years(age(visits.visitdate, subjects.birthdate)) AS visit_visitage
  FROM
    visits
  LEFT OUTER JOIN waves ON
    visits.wave_code = waves.code
    AND visits.project_id = waves.project_id
  LEFT OUTER JOIN subjects ON
    visits.subject_id = subjects.id
  LEFT OUTER JOIN projects ON
    visits.project_id = projects.id
;


-- Add metadata for core table

INSERT INTO metatables (id, sampletype, idx, title) VALUES ('core', 'core', 0, 'Core data');
UPDATE metatables SET descr = 'Basic data for any participant' where id = 'core';

INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'subject_id',           0, 'Subject ID');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'project_id',           1, 'Project ID');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'wave_code',            2, 'Wave code');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'subject_sex',          3, 'Sex');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'subject_birthdate',    4, 'Birth date');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'subject_shareable',    5, 'Shareable');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'visit_visitdate',      6, 'Visit date');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'visit_visitage',       7, 'Age at visit');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'project_name',         8, 'Project name');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'project_code',         9, 'Project code');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'project_description', 10, 'Project description');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'wave_description',    11, 'Wave description');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'wave_reknr',          12, 'Wave REK Nr.');

UPDATE metacolumns SET descr = '(visitdate - birthdate); #Y+(#M*365/12+#D)/365' where id = 'visit_visitage';
