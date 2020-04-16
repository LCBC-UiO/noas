SELECT * FROM tmp_{table_name} {table_name}
  WHERE ({table_name}.subject_id, {table_name}.project_id, {table_name}.wave_code) in (SELECT subject_id, project_id, wave_code FROM visit);

CREATE TABLE IF NOT EXISTS {table_name} (
  LIKE tmp_{table_name} including ALL,
  constraint {table_name}_pk PRIMARY KEY (subject_id, project_id, wave_code),
  constraint {table_name}_visit_fk FOREIGN KEY (subject_id, project_id, wave_code) REFERENCES visit(subject_id, project_id, wave_code)
);

INSERT INTO {table_name} 
  SELECT * FROM tmp_{table_name} {table_name}
  WHERE ({table_name}.subject_id, {table_name}.project_id, {table_name}.wave_code) IN (SELECT subject_id, project_id, wave_code FROM visit);
