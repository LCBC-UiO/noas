DROP VIEW IF EXISTS noas_core;

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
DROP TYPE IF EXISTS e_columntype CASCADE;


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