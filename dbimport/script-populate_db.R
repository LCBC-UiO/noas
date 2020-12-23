#!/usr/bin/env Rscript

options("stringsAsFactors" = FALSE)

# get helper functions
source('dbimport/funcs-utils.R')
source('dbimport/funcs-populate.R')


.get_env <- function(envkey, default) {
  v <- Sys.getenv(envkey)
  return(ifelse(v=="", default, v))
}

args <- commandArgs(trailingOnly = TRUE)
if(length(args) > 0) args <- match.arg(args, c("unicode", "ascii"))

cat_type <- if(!isatty(stdout())||length(args) == 0||args == "unicode"){ "unicode" }else{ "ascii" }

# establish connection
con <- moasdb_connect()

j <- DBI::dbExecute(con, 
                    read_sql("dbimport/sql/init_db.sql"))
# NOTE: convert these parameters to positional command line arguments?
DBI::dbExecute(con, 
              "INSERT INTO versions (id, label, ts) VALUES ($1, $2, $3)",
              params=list(
                .get_env("NOAS_IMPORT_ID",    sprintf("undefined (%s)", as.character(date()))),
                .get_env("NOAS_IMPORT_LABEL", "unnamed version"),
                .get_env("NOAS_IMPORT_DATE",  date())
              ))

start <- Sys.time()

populate_core(con, cat_type = cat_type)
populate_table("long", con, cat_type = cat_type)
populate_table("repeated", con, cat_type = cat_type)
populate_table("cross", con, cat_type = cat_type)

spent <- round(as.numeric(Sys.time() - start, units="mins"), 3)

spent <- (function(){
  if (spent < 5)  return(codes(cat_type, FALSE)$success(spent))
  if (spent > 10) return(codes(cat_type, FALSE)$fail(spent))
  return(codes(cat_type, FALSE)$note(spent))
})()

cat("\n ---------- \n")
cat_table_success(TRUE,
                  codes(cat_type)$bold("Database populated in", spent, "minutes"),
                  cat_type = cat_type)

