select * from tmp_{table_name} {table_name}
where ({table_name}.subject_id, {table_name}.project_id, {table_name}.wave_code) in (select subject_id, project_id, wave_code from visit);
create table if not exists {table_name} (
like tmp_{table_name} including all,
constraint {table_name}_pk primary key (subject_id, project_id, wave_code),
constraint {table_name}_visit_fk FOREIGN KEY (subject_id, project_id, wave_code) REFERENCES visit(subject_id, project_id, wave_code)
);

insert into {table_name} 
select * from tmp_{table_name} {table_name}
where ({table_name}.subject_id, {table_name}.project_id, {table_name}.wave_code) in (select subject_id, project_id, wave_code from visit);
