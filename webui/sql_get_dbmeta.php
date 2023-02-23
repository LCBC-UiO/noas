<?php
function sql_getdbmeta($prj) {
return "
with vers as ( select * from versions limit 1)
select
  jsonb_build_object(
    'version'
    , jsonb_build_object(
        'id',               (select id               from vers)
      , 'label',            (select label            from vers)
      , 'ts',               (select ts               from vers)
      , 'import_completed', (select import_completed from vers)
    )
    ,'tables'
    , array_to_json(array_agg(json_strip_nulls(row_to_json(t))))
    ,'project'
    , (select '{$prj}')
  ) as meta_json
from (
  select
    mt.id,
    array_to_json(mt.category) as category,
    mt.sampletype,
    mt.title,
    mt.idx,
    mt.descr,
    (
			select row_count(mt.sampletype, mt.id, '{$prj}')
		) as n,
    (
      select jsonb_build_object(
        'col_id'
        , metacolumn_id
        ,'group_id'
        , repeated_group
      )
      from meta_repeated_grps where metatable_id = mt.id
		) as repeated_group,
    (
    select 
      array_to_json(array_agg(row_to_json(d)))
    from (
      select
        -- skip '_'-prefix in column ID for all non-core tables
        (case when mt.idx = 0 then mc.id else substr(mc.id, 2) end) as id,
        mc.title,
        mc.idx,
        mc.descr,
        mc.type
      from
        metacolumns mc
      where
        mt.id = mc.metatable_id AND
        -- do not include the 4th col if its repeated
        NOT EXISTS (
          SELECT 1
          FROM meta_repeated_grps
          WHERE metatable_id = mt.id
            AND metacolumn_id = mc.id
        )
      order by
        mc.idx, mc.id
      ) d 
    ) as columns
  from
    metatables mt
  order by
    mt.idx,
    array_length(mt.category, 1) > 0,
    array_to_string(mt.category, ', '),
    mt.title
) t
";
}

?>