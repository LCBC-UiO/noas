
-- drop tables if they exist
-- creates a script to delete all long_* tables
DO
$do$
DECLARE
   _tbl text;
BEGIN
FOR _tbl  IN
    SELECT quote_ident(category) || '_'
        || quote_ident(id)      -- escape identifier and schema-qualify!
    FROM   metatables
 --   WHERE  category = 'long'  -- your table name prefix
LOOP
  -- RAISE NOTICE '%',
   EXECUTE
  'DROP TABLE ' || _tbl;  -- see below
END LOOP;
END
$do$;

-- DROP TABLE IF EXISTS long_ehi CASCADE;
-- DROP TABLE IF EXISTS long_cvlt CASCADE;

DROP TABLE IF EXISTS projects CASCADE;
DROP TABLE IF EXISTS waves CASCADE;
DROP TABLE IF EXISTS subjects CASCADE;
DROP TABLE IF EXISTS visits CASCADE;
DROP TABLE IF EXISTS metatables CASCADE;
DROP TABLE IF EXISTS metacolumns CASCADE;

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
  name text,
  CONSTRAINT metacolumns_pk PRIMARY KEY (metatable_id, id),
  CONSTRAINT metacolumns_fk FOREIGN KEY (metatable_id) REFERENCES metatables(id)
);

