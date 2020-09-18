<?php

$sql_getdbmeta = "
select
  jsonb_build_object(
    'tables'
    , array_to_json(array_agg(row_to_json(t)))
  ) as meta_json
from (
  select
    mt.id,
    mt.category,
    mt.sampletype,
    mt.title,
    mt.idx,
    (
			select row_count(mt.sampletype, mt.id)
		) as n,
    (
    select 
      array_to_json(array_agg(row_to_json(d)))
    from (
      select
        -- skip '_'-prefix in column ID for all non-core tables
        (case when mt.idx = 0 then mc.id else substr(mc.id, 2) end) as id,
        mc.title,
        mc.idx
      from
        metacolumns mc
      where
        mt.id = mc.metatable_id
      order by
        mc.idx 
      ) d 
    ) as columns
  from
    metatables mt
  order by
    mt.idx,
    mt.category,
    mt.title
) t
";

?>