<?php

function sel_to_rimport($sel) {
$cs = array();
  foreach ($sel->columns as $ec) {
    array_push($cs, "    { \"table_id\": \"$ec->table_id\", \"column_id\": \"$ec->column_id\" }");
  }
  $sc = join(",\n", $cs);
  $s = <<< EOD
d_noas <- (function(){
  selection <- '{ "columns": [
$sc
  ], "set_op": "$sel->set_op", "project": "$sel->project"
  , "version": "$sel->version" }'
  header <- paste0(c(NULL
    ,'POST /query_tsv.php HTTP/1.0'
    ,'Content-Type: application/json'
    ,sprintf('Content-Length: %d', nchar(selection))
    ,'Connection: close'
  ), collapse='\\r\\n')
  con <- socketConnection(host='${_SERVER['SERVER_NAME']}', port=${_SERVER['SERVER_PORT']}, blocking=T, server=F, open='r+')
  on.exit(close(con))
  write(sprintf('%s\\r\\n\\r\\n%s', header, selection), con);
  pl_str <- paste0(readLines(con), collapse='\\n'); # receive data
  table_str <- substr(pl_str, regexpr('\\n\\n', pl_str)+2, nchar(pl_str)); # skip http header
  return(read.table(text=table_str, header=T, sep='\\t', na.strings='None', stringsAsFactors=F))
})()\n
EOD;
    return $s;
  }

?>