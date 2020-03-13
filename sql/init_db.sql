
DROP VIEW IF EXISTS core;
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
  sex text NULL,
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


-- Create table of tables

CREATE TABLE metatables (
  id text,
  category text,
  name text,
  CONSTRAINT metatables_pk PRIMARY KEY(id)
);

-- Create table of tables

CREATE TABLE metacolumns (
  metatable_id text,
  id text,
  rank integer DEFAULT 0,
  name text,
  CONSTRAINT metacolumns_pk PRIMARY KEY (metatable_id, id),
  CONSTRAINT metacolumns_fk FOREIGN KEY (metatable_id) REFERENCES metatables(id)
);

-- Combine core tables

CREATE VIEW core AS
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
    projects.description AS project_desciption
  FROM
    visits
  LEFT OUTER JOIN waves ON
    visits.wave_code = waves.code
    and visits.project_id = waves.project_id
  LEFT OUTER JOIN subjects ON
    visits.subject_id = subjects.id
  LEFT OUTER JOIN projects ON
    visits.project_id = projects.id
