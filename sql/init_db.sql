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

-- Create table of tables

CREATE TABLE metatables (
  id text,
  sampletype e_sampletype,
  category   text,
  idx        integer DEFAULT 1,
  title      text,
  CONSTRAINT metatables_pk PRIMARY KEY(id)
);


-- Create table of table comlumns

CREATE TABLE metacolumns (
  metatable_id text,
  id    text,
  idx   integer DEFAULT 1,
  title text,
  CONSTRAINT metacolumns_pk PRIMARY KEY (metatable_id, id),
  CONSTRAINT metacolumns_fk FOREIGN KEY (metatable_id) REFERENCES metatables(id)
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
    projects.description AS project_description
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
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'subject_id',          0, 'Subject ID');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'project_id',          1, 'Project ID');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'wave_code',           2, 'Wave code');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'subject_sex',         3, 'Sex');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'subject_birthdate',   4, 'Birth date');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'subject_shareable',   5, 'Sharable');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'visit_visitdate',     6, 'Visit date');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'project_name',        7, 'Project name');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'project_code',        8, 'Project code');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'project_description', 9, 'Project description');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'wave_description',   10, 'Wave description');
INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES ('core', 'wave_reknr',         11, 'Wave REK Nr.');


--------------------------------------------------------------------------------

-- Define functions

-- Count number of rows for a table 
-- (this is similart to "count(*)"" but works with a parameter of type "text")
CREATE OR REPLACE FUNCTION row_count (metatable_sampletype e_sampletype, metatable_id text)
RETURNS integer AS $total$
DECLARE
	total integer;
BEGIN
   EXECUTE format('select count(*) from %I', metatable_sampletype || '_' || metatable_id) INTO total;
   RETURN total;
END;
$total$ LANGUAGE plpgsql;
