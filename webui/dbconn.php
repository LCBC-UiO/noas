<?php

function dbconnect() {
  // Construct the DSN string including the password
  $conStr = sprintf("pgsql:host=%s;port=%d;dbname=%s;user=%s;password=%s", 
    getenv('DBHOST'), 
    getenv('DBPORT'), 
    getenv('POSTGRES_DB'),  // Use POSTGRES_DB consistent with .env
    getenv('POSTGRES_USER'), // Use POSTGRES_USER consistent with .env
    getenv('POSTGRES_PASSWORD') // Get password from environment
  );

  try {
    $pdo = new PDO($conStr);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    return $pdo;
  } catch (PDOException $e) {
    // Handle connection error (log it, return null, or re-throw)
    // For debugging, you might print the error, but don't do this in production
    error_log("Database Connection Error: " . $e->getMessage()); 
    // Depending on how the calling code handles errors, you might:
    // return null; 
    // or re-throw the exception:
    throw $e;
  }
}

?>
