-- create temporary table in order to check against existing data
SELECT * FROM tmp_{table_name} t
  WHERE (t.subject_id, t.project_id, t.wave_code) IN (SELECT subject_id, project_id, wave_code FROM visits);

-- make keys into specific types
ALTER TABLE tmp_{table_name} 
  ALTER column subject_id TYPE int,
  ALTER column project_id TYPE text,
  ALTER column wave_code TYPE numeric(3,1);

-- to suppress the notice that the table might already exist
SET client_min_messages = error;

-- define the table
CREATE TABLE IF NOT EXISTS long_{table_name} (
  LIKE tmp_{table_name} including ALL,
  constraint {table_name}_pk PRIMARY KEY (subject_id, project_id, wave_code),
  constraint {table_name}_visit_fk FOREIGN KEY (subject_id, project_id, wave_code) REFERENCES visits(subject_id, project_id, wave_code)
);

-- reset the notice suppression, so it will not contaminate other later messages
SELECT set_config('client_min_messages', 'error', true);

-- copy temporary data to defined table
INSERT INTO long_{table_name} 
  SELECT * FROM tmp_{table_name} t
  WHERE (t.subject_id, t.project_id, t.wave_code) IN (SELECT subject_id, project_id, wave_code FROM visits);


INSERT INTO metatables (id, sampletype, title)
  VALUES ('{table_name}', 'long', INITCAP('{table_name}'))
  ON conflict (id) do nothing;

-- add default meta data (columns)

DO
$do$
DECLARE
   _tbl text;
BEGIN
FOR _tbl IN
  SELECT column_name
      FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'long_{table_name}'
      AND column_name  like '\_%'
LOOP
  EXECUTE 
  'INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES (''{table_name}'', ''' || _tbl || ''',  1, ''' || INITCAP(REPLACE(SUBSTRING(_tbl, 2), '_', ' ')) || ''') ON CONFLICT DO NOTHING';
END LOOP;
END
$do$;
