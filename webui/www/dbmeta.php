<?php 

require '../dbconn.php';

header("Content-Type: application/json; charset=UTF-8");

$response = array(
  'status_ok' => false,
  'status_msg' => "undefined",
  'type' => "dbmeta",
);

function exit_error($code, $response, $msg) {
  http_response_code($code);
  $response['status_msg'] = $msg;
  echo json_encode($response);
  exit;
}

$sql_getmeta = "
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
        mc.id,
        mc.title,
        mc.idx
      from
        metacolumns mc
      where
        mt.id = mc.metatable_id
      order by
        mc.idx 
      ) d 
    ) as cols
  from
    metatables mt
  order by
    mt.idx,
    mt.category,
    mt.title
) t
";

try {
  $db = dbconnect();
  $stmt = $db->prepare($sql_getmeta);
  $stmt->execute();
  $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
  $meta_json = json_decode($results[0]["meta_json"]);
  $response['status_ok'] = true;
  $response['status_msg'] = "ok";
  $response['data'] = $meta_json;
} catch (PDOException $e) {
  exit_error(400, $response, htmlentities($e->getMessage()));
}
$db = null;

http_response_code(200);
header("Content-Type: application/json; charset=UTF-8");
echo json_encode($response);

?>