<?php

function dbconnect() {
  $conStr = sprintf("pgsql:host=%s;port=%d;dbname=%s;user=%s", 
    getenv('DBHOST'), 
    getenv('DBPORT'), 
    getenv('DBNAME'),  
    getenv('DBUSER'), 
  );
  $pdo = new PDO($conStr);
  $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
  return $pdo;
}

?>
