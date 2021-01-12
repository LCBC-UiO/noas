<?php 

require '../dbconn.php';
require '../sql_get_dbmeta.php';
require '../sql_build_query.php';

header("Content-Type: text/plain; charset=UTF-8");

/*----------------------------------------------------------------------------*/

function exit_error($code, $msg) {
  http_response_code($code);
  echo $msg;
  exit;
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
  // output
  $handle = fopen("php://output", "w");
  http_response_code(200);
  // write header
  fputcsv(
    $handle, 
    array_map(
      function($i) use ($stmt) { return $stmt->getColumnMeta($i)['name']; },
      range(0, $stmt->columnCount()-1)
    ),
    "\t"
  );
  // write rows
  while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    fputcsv($handle, $row, "\t");
  }
  fclose($handle);
} catch (PDOException $e) {
  exit_error(400, htmlentities($e->getMessage()));
} catch (Exception $e) {
  exit_error(400, htmlentities($e->getMessage()));
}
$db = null;

?>