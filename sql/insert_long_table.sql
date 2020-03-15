-- create temporary table in order to check against existing data
select * from tmp_{table_name} t
where (t.subject_id, t.project_id, t.wave_code) in (select subject_id, project_id, wave_code from visits);

-- define the table
create table if not exists long_{table_name} (
like tmp_{table_name} including all,
constraint {table_name}_pk primary key (subject_id, project_id, wave_code),
constraint {table_name}_visit_fk FOREIGN KEY (subject_id, project_id, wave_code) REFERENCES visits(subject_id, project_id, wave_code)
);

-- copy temporary data to defined table
insert into long_{table_name} 
select * from tmp_{table_name} t
where (t.subject_id, t.project_id, t.wave_code) in (select subject_id, project_id, wave_code from visits);

-- add meta data (table)

insert into metatables (id, category, title)
values ('{table_name}', 'long', INITCAP('{table_name}')) --TODO: use name from meta-data files
on conflict (id) do nothing;


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
      AND table_name   = 'long_{table_name}'
      AND column_name  like '\_%'
LOOP
  EXECUTE 
  'INSERT INTO metacolumns (metatable_id, id, idx, title) VALUES (''{table_name}'', ''' || _tbl || ''',  1, ''' || INITCAP(REPLACE(SUBSTRING(_tbl, 2), '_', ' ')) || ''') ON CONFLICT DO NOTHING';
END LOOP;
END
$do$;
