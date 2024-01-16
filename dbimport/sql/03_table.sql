
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
  "date" date,
  "number" integer ,
  age numeric,
  interval_bl float,
  interval_prev float,
  CONSTRAINT visit_pk PRIMARY KEY(subject_id, wave_code, project_id),
  CONSTRAINT visit_subject_fk FOREIGN KEY (subject_id) REFERENCES subjects(id),
  CONSTRAINT visit_wave_fk FOREIGN KEY (wave_code, project_id) REFERENCES waves(code, project_id)
);

-- Create trigger to enforce visit age validation
CREATE TRIGGER visit_age_validation
BEFORE INSERT OR UPDATE ON visits
FOR EACH ROW
EXECUTE PROCEDURE validate_visit_age();

-- -- Create trigger to enforce visit date validation
CREATE TRIGGER visit_date_validation
BEFORE INSERT OR UPDATE ON visits
FOR EACH ROW
EXECUTE PROCEDURE validate_visit_date();
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
