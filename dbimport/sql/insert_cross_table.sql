-- create temporary table in order to check against existing data
SELECT * FROM tmp_{table_name} t
  WHERE (t.subject_id) IN (SELECT id FROM subjects);

-- make keys into specific types
ALTER TABLE tmp_{table_name} 
  ALTER column subject_id TYPE int;

-- to suppress the notice that the table might already exist
SET client_min_messages = error;

-- define the table
CREATE TABLE IF NOT EXISTS cross_{table_name} (
  LIKE tmp_{table_name} including ALL,
  constraint {table_name}_pk PRIMARY KEY (subject_id),
  constraint {table_name}_visit_fk FOREIGN KEY (subject_id) REFERENCES subjects(id)
);

-- reset the notice suppression, so it will not contaminate other later messages
SELECT set_config('client_min_messages', 'error', true);

-- copy temporary data to defined table
INSERT INTO cross_{table_name} 
  SELECT * FROM tmp_{table_name} t
  WHERE (t.subject_id) IN (SELECT id FROM subjects);

-- add meta data (table)

INSERT INTO metatables (id, sampletype, title)
  VALUES ('{table_name}', 'cross', INITCAP('{table_name}')) --TODO: use name FROM meta-data files
  ON conflict (id) do nothing;


-- add meta data (columns)

-- TODO: Replace the code below.
--       This data in meatacolumns will have to come FROM some meta-data files
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
      AND table_name   = 'cross_{table_name}'
      AND column_name  like '\_%'
LOOP
  EXECUTE 
  'INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES (''{table_name}'', ''' || _tbl || ''',  1, ''' || INITCAP(REPLACE(SUBSTRING(_tbl, 2), '_', ' ')) || ''') ON CONFLICT DO NOTHING';
END LOOP;
END
$do$;
