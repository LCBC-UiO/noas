-- create temporary table in order to check against existing data
SELECT * FROM tmp_{table_name} t
  WHERE (t.subject_id, t.project_id, t.wave_code) IN (SELECT subject_id, project_id, wave_code FROM visits);

-- make keys into specific types
ALTER TABLE tmp_{table_name} 
  ALTER column subject_id TYPE int,
  ALTER column project_id TYPE text,
  ALTER column wave_code TYPE numeric(2,1);

-- define the table
CREATE TABLE IF NOT EXISTS repeated_{table_name} (
  like tmp_{table_name} including ALL,
  constraint {table_name}_pk PRIMARY KEY (subject_id, project_id, wave_code, visit_id),
  constraint {table_name}_visit_fk FOREIGN KEY (subject_id, project_id, wave_code) REFERENCES visits(subject_id, project_id, wave_code)
);

-- copy temporary data to defined table
INSERT INTO repeated_{table_name} 
  SELECT * FROM tmp_{table_name} t
  WHERE (t.subject_id, t.project_id, t.wave_code) IN (SELECT subject_id, project_id, wave_code FROM visits);

-- add meta data (table)

INSERT INTO metatables (id, category, title)
  VALUES ('{table_name}', 'repeated', INITCAP('{table_name}')) --TODO: use name from meta-data files
  ON conflict (id) do nothing;


-- add meta data (columns)

-- TODO: Replace the code below.
--       This data in meatacolumns will have to come from some meta-data files
--       For now is just some auto-generated stuff.
DO
$do$
DECLARE
   _tbl text;
BEGIN
FOR _tbl IN
  SELECT column_name
      FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'repeated_{table_name}'
      AND column_name  like '\_%'
LOOP
  EXECUTE 
  'INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES (''{table_name}'', ''' || _tbl || ''',  1, ''' || INITCAP(REPLACE(SUBSTRING(_tbl, 2), '_', ' ')) || ''') ON CONFLICT DO NOTHING';
END LOOP;
END
$do$;
