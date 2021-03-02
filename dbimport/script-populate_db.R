#!/usr/bin/env Rscript

options(
  #warn = 2, # error on warnings
  "stringsAsFactors" = FALSE
)

# get helper functions
source('dbimport/funcs-table.R')

.get_env <- function(envkey, default) {
  v <- Sys.getenv(envkey)
  ifelse(v == "", default, v)
}

curr_date <- date()
noas_import_id <- .get_env(
  "NOAS_IMPORT_ID",
  sprintf("undefined (%s)", as.character(curr_date))
)

# establish connection
con <- moasdb_connect()

j <- DBI::dbExecute(
  con,
  read_sql("dbimport/sql/init_db.sql")
)

# NOTE: convert these parameters to positional command line arguments?
invisible(DBI::dbExecute(
  con,
  "INSERT INTO versions (id, label, ts) VALUES ($1, $2, $3)",
  params=list(
    noas_import_id,
    .get_env("NOAS_IMPORT_LABEL", "unnamed version"),
    .get_env("NOAS_IMPORT_DATE",  curr_date)
  )))

start <- Sys.time()

populate_core(con)
cat(" ----------\n")
populate_tables(con)

stopifnot(
  DBI::dbExecute(con,
                 "UPDATE versions SET import_completed=TRUE WHERE id = $1",
                 params=list(noas_import_id)) == 1)

spent <- round(as.numeric(Sys.time() - start, units="mins"), 3)

spent <- (function(){
  if (spent < 5)  return(codes(FALSE)$success(spent))
  if (spent > 10) return(codes(FALSE)$fail(spent))
  return(codes(FALSE)$note(spent))
})()

cat("\n ---------- \n")
cat_table_success(TRUE,
                  sprintf("Database populated in %s minutes", spent))

