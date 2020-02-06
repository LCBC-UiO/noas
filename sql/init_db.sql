DROP TABLE IF EXISTS project CASCADE;
DROP TABLE IF EXISTS wave CASCADE;
DROP TABLE IF EXISTS subject CASCADE;
DROP TABLE IF EXISTS visit CASCADE;
DROP TABLE IF EXISTS visits CASCADE;
DROP TABLE IF EXISTS cog_cvlt CASCADE;
DROP TABLE IF EXISTS participant CASCADE;
DROP TABLE IF EXISTS participants CASCADE;
DROP TABLE IF EXISTS project_wave CASCADE;

-- Create project table

CREATE TABLE project (
  id text NOT NULL,
  code int4 NOT NULL,
  name text NULL,
  description text NULL,
  CONSTRAINT project_pkey PRIMARY KEY (id)
);

-- Create wave table

CREATE TABLE wave (
  code float NOT NULL,
  project_id text NOT NULL,
  reknr int4 NULL,
  description text NULL,
  CONSTRAINT wave_pkey PRIMARY KEY (code, project_id),
  CONSTRAINT wave_project_fk FOREIGN KEY (project_id) REFERENCES project(id)
);


-- Create subject table

CREATE TABLE subject (
  id int8 NOT NULL,
  birthdate date NULL,
  sex text NULL,
  shareable integer NULL,
  CONSTRAINT subject_pk PRIMARY KEY (id)
);


-- Create visit table

CREATE TABLE visit (
  subject_id int8 NOT NULL,
  project_id text,
  wave_code float,
  visitdate date,
  CONSTRAINT visit_pk PRIMARY KEY(subject_id, wave_code, project_id)
);

ALTER TABLE visit ADD CONSTRAINT visit_subject_fk FOREIGN KEY (subject_id) REFERENCES subject(id);
ALTER TABLE visit ADD CONSTRAINT visit_wave_fk FOREIGN KEY (wave_code, project_id) REFERENCES wave(code, project_id);
