<?php

require '../sel_to_rimport.php';

header("Content-Type: text/plain; charset=UTF-8");

/*----------------------------------------------------------------------------*/

try {
  // get input selection
  $sel = json_decode(file_get_contents('php://input'));
  if (is_null($sel)) {
    throw new Exception('Undefined selection.');
  }
  $s = sel_to_rimport($sel);
  http_response_code(200);
  $handle = fopen("php://output", "w");
  fwrite($handle, $s);
  fclose($handle);
} catch (Exception $e) {
  http_response_code(400);
  echo htmlentities($e->getMessage());
  exit;
}
$db = null;

?>
