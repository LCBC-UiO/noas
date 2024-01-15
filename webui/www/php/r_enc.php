<?php

# test:
# curl -d @/home/fkrull/Downloads/noas_selection_2021-02-16_20-28-43_c83503d_undefin.json \
#   -H "Content-Type: application/json" \
#   -X POST http://localhost:3880/r_enc.php?password="lcbclcbc" \ 
#   > /tmp/my_encrypted_sensitive_data.R

require '../../sel_to_rimport.php';

header("Content-Type: text/plain; charset=UTF-8");

/*----------------------------------------------------------------------------*/

try {
  // get password
  $password = $_GET["password"];
  if ($password == null || strlen($password) < 8) {
    throw new Exception("error - password missing / too short");
  }
  // get input selection
  $selstr = file_get_contents('php://input');
  $selection = json_decode($selstr);
  if (is_null($selection)) {
    throw new Exception('Undefined selection.');
  }
  $descriptorspec = array(
    0 => array("pipe", "r"),
    1 => array("pipe", "w"),
    2 => array("pipe", "w") 
  );
  $process = proc_open("Rscript -", $descriptorspec, $pipes);
  if (!is_resource($process)) {
    throw new Exception("error - Rscript");
  }
  $rimport = sel_to_rimport($selection);
  fwrite($pipes[0], $rimport . PHP_EOL);
  fwrite($pipes[0], <<< EOD
password <- "{$password}"
noas_selection <- '{$selstr}'
source(sprintf("%s/webui/opt/r_selfenc.R", Sys.getenv("BASEDIR")))
EOD
  );
  fclose($pipes[0]);
  $std_out = stream_get_contents($pipes[1]);
  $std_err = stream_get_contents($pipes[2]);
  $return_value = proc_close($process);
  if ($return_value != 0) {
    throw new Exception("error - " . $std_err); 
  }
  http_response_code(200);
  $handle = fopen("php://output", "w");
  fwrite($handle, $std_out . PHP_EOL);
  fclose($handle);
} catch (Exception $e) {
  http_response_code(400);
  echo htmlentities($e->getMessage());
  exit;
}

?>
