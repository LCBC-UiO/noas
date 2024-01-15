
CREATE VIEW noas_core AS
  SELECT
    v.subject_id,
    s.birthdate AS subject_birthdate,
    s.sex AS subject_sex,
    s.shareable AS subject_shareable,
    v.alt_subj_id AS visit_alt_subj_id,
    v.age AS visit_age,
    v.date AS visit_date,
    v.number AS visit_number,
    v.interval_bl AS visit_interval_bl,
    v.interval_prev AS visit_interval_prev,
    w.reknr AS wave_reknr,
    w.description AS wave_description,
    w.code AS wave_code,
    p.id AS project_id,
    p.name AS project_name,
    p.code AS project_code,
    p.description AS project_description
  FROM (
    SELECT 
    *
    FROM visits
  ) AS v
  LEFT JOIN waves AS w ON v.wave_code = w.code AND v.project_id = w.project_id
  LEFT JOIN subjects AS s ON v.subject_id = s.id
  LEFT JOIN projects AS p ON v.project_id = p.id;


INSERT INTO metatables (id, sampletype, idx, title) VALUES ('core', 'core', 0, 'Core data');
UPDATE metatables SET descr = 'Basic data for any participant' where id = 'core';

INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'subject_id',           0, 'integer', 'Subject ID');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'project_id',           1, 'text',    'Project ID');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'wave_code',            2, 'float',   'Wave code');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'subject_sex',          3, 'text',    'Sex');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'subject_birthdate',    4, 'date',    'Birth date');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'subject_shareable',    5, 'boolean', 'Shareable');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'visit_alt_subj_id',    6, 'text',    'Alternate Subject ID');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'visit_date',           7, 'date',    'Visit date');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'visit_age',            8, 'float',   'Age at visit');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'visit_number',         9, 'integer', 'Visit number');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'visit_interval_bl',   10, 'float',   'Interval from baseline');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'project_name',        11, 'text',    'Project name');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'project_code',        12, 'integer', 'Project code');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'project_description', 13, 'text',    'Project description');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'wave_description',    14, 'text',    'Wave description');
INSERT INTO metacolumns (metatable_id, id, idx, type, title) VALUES ('core', 'wave_reknr',          15, 'integer', 'Wave REK Nr.');

UPDATE metacolumns SET descr = '(visit_date - subject_birthdate); #Y+(#M*365/12+#D)/365' where id = 'visit_age';
UPDATE metacolumns SET descr = 'Subject id at the time of data collection for older projects with different ID systems than now, and participants that have joined several projects under different IDs.' where id = 'visit_alt_subj_id';
UPDATE metacolumns SET descr = 'Date of cognitive testing. If this is missing, MRI date. If both these are missing, an approximate date is calculated using birthdate and age recorded at testing (old data).' where id = 'visit_date';
UPDATE metacolumns SET descr = 'Sequential counter of visits. Increases by one for each time a subject is assessed for a project wave of data collection.' where id = 'visit_number';
UPDATE metacolumns SET descr = 'Interval from baseline in decimal years' where id = 'visit_interval_bl';