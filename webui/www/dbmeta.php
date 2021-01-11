<?php 

require '../dbconn.php';
require '../sql_get_dbmeta.php';

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

try {
  $db = dbconnect();
  $stmt = $db->prepare($sql_getdbmeta);
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