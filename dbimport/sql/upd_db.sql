-- get duration in years - used for age at visit
CREATE OR REPLACE FUNCTION diff_years(date_val1 date, date_val2 date)
RETURNS NUMERIC AS $$
DECLARE
    age INTERVAL;
BEGIN
      age := AGE(date_val1, date_val2);
    RETURN EXTRACT  ('year'  FROM age)
           + EXTRACT('month' FROM age) / 12.0
           + EXTRACT('day'   FROM age) / 365.25;
END;
$$ LANGUAGE plpgsql;


-- Calculate and update "number" and "interval"
WITH visit_data AS (
  SELECT
    v.subject_id,
    v."date",
    s.birthdate,
    ROW_NUMBER() OVER (PARTITION BY s.id ORDER BY v."date") AS visit_number,
    --ROW_NUMBER() OVER (PARTITION BY v.subject_id ORDER BY v."date") AS visit_number,
    LAG(v."date") OVER (PARTITION BY v.subject_id ORDER BY v."date") AS previous_visit_date,
    MIN(v."date") OVER (PARTITION BY v.subject_id) AS baseline_date
  FROM
    visits v
    JOIN subjects s ON v.subject_id = s.id
)
UPDATE visits AS v
SET

  age = diff_years(v."date", vd.birthdate),
  "number" = vd.visit_number,
  interval_prev = COALESCE(diff_years(v."date", vd.previous_visit_date), 0),
  interval_bl = diff_years(v."date", vd.baseline_date)
FROM visit_data vd
WHERE v.subject_id = vd.subject_id AND v."date" = vd."date";
