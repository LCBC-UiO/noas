-- add meta data (table)
INSERT INTO metatables (id, category, title)
  VALUES ('{table_name}', '{category}', '{title}')
  ON conflict (id) do nothing;


--INSERT INTO metatables (id, table_type, category, title)
--  VALUES ('{table_name}', '{table_type}', '{category}', '{title}')
--  ON conflict (id) do nothing;


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
      AND table_name   = 'long_{table_name}'
      AND column_name  like '\_%'
LOOP
  EXECUTE 
  'INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES (''{table_name}'', ''' || _tbl || ''',  1, ''' || INITCAP(REPLACE(SUBSTRING(_tbl, 2), '_', ' ')) || ''') ON CONFLICT DO NOTHING';
END LOOP;
END
$do$;
