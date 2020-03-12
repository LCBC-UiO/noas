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


insert into metatables 
values ('{table_name}', 'long')
on conflict (id) do nothing;

