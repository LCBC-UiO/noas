<?php 

require '../dbconn.php';
require '../sql_get_dbmeta.php';
require '../sql_build_query.php';

ini_set('memory_limit', '1024M');
header("Content-Type: application/json; charset=UTF-8");

$response = array(
  'status_ok' => false,
  'status_msg' => "undefined",
  'type' => "query_result",
);

/*----------------------------------------------------------------------------*/

function exit_error($code, $response, $msg) {
  http_response_code($code);
  $response['status_msg'] = $msg;
  echo json_encode($response);
  exit;
}

/*----------------------------------------------------------------------------*/

function _get_column_def($stmt) {
  function _get_col_def($i, $stmt) {
    $type = 'text';
    switch ($stmt->getColumnMeta($i)['native_type']) {
      case "text":
        $type = "text";
        break;
      case "float8":
        $type = "float";
        break;
      case "float4":
        $type = "float";
        break;
      case "int8":
        $type = "int";
        break;
      case "int4":
        $type = "int";
        break;
      case "date":
        $type = "date";
        break;
    }
    return array(
      "id" => $stmt->getColumnMeta($i)['name'],
      "idx" => $i,
      "type" => $type,
      "dbg_type" => $stmt->getColumnMeta($i)['native_type'],
    );
  }
  return array_map(
    function($i) use ($stmt) { return _get_col_def($i, $stmt); },
    range(0, $stmt->columnCount()-1)
  );
}

/*----------------------------------------------------------------------------*/

try {
  // get input selection
  $selection = json_decode(file_get_contents('php://input'));
  if (is_null($selection)) {
    throw new Exception('Undefined selection.');
  }
  // get noas meta
  $db = dbconnect();
  $stmt = $db->prepare(sql_getdbmeta($selection->project));
  $stmt->execute();
  $dbmeta = $stmt->fetchAll(PDO::FETCH_ASSOC);
  $dbmeta = json_decode($dbmeta[0]["meta_json"]);
  // generate sql query string
  $sql_gettable = sql_build_query($dbmeta, $selection);
  // run db query
  $stmt = $db->prepare($sql_gettable);
  $stmt->execute();
  $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
  // output
  $response['status_ok'] = true;
  $response['status_msg'] = "ok";
  $response['data'] = array(
    "column_def" => _get_column_def($stmt),
    "rows" => $results,
    "date" => (new DateTime())->format('c')
  );
} catch (PDOException $e) {
  exit_error(400, $response, htmlentities($e->getMessage()));
} catch (Exception $e) {
  exit_error(400, $response, htmlentities($e->getMessage()));
}
$db = null;

http_response_code(200);
echo json_encode($response);

?>
