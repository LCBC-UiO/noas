#!/usr/bin/env Rscript
source('dbimport/funcs-utils.R')

# set global R options
options(
  stringsAsFactors = FALSE,
  warn = 2, # error on warnings
  noas = read_config()
)

# connect to DB
con <- DBI::dbConnect(
  RPostgreSQL::'PostgreSQL'(), #":memory:",
  user   = getOption("noas")$DBUSER,
  port   = getOption("noas")$DBPORT,
  dbname = getOption("noas")$DBNAME,
  host   = getOption("noas")$DBHOST
)

# start atomic transaction, changes in this con won't be visible until the commit
invisible(DBI::dbBegin(con))

# initiate DB
invisible(DBI::dbExecute(con, read_file("dbimport/sql/init_db.sql")))

# import core
#   - list files
core_dir <- file.path(getOption("noas")$TABDIR, "core")
core_files <- list.files(core_dir)

core_pre_seq <- c("projects", "waves", "subjects", "visits")

#   - loop through prefixes (order by sequences needed)
cli::cli_h1("Importing core data")
for(pre in core_pre_seq){
  core_files_cur <- core_files[grep(pre, core_files)]
  core_files <- setdiff(core_files, core_files_cur)

  check_tsvs(core_files_cur, core_dir)

  for(f in core_files_cur){
    cli::cli_progress_step(f)
    DBI::dbWriteTable(
      con,
      pre,
      read_noas_table(file.path(core_dir, f)),
      append = TRUE,
      row.name = FALSE
    )
    cli::cli_progress_done()
  }
}
# error if still something in file list after loop
fail_if(length(core_files) > 0,
        "There are unhandled files in ", core_dir)


# update core visits
invisible(DBI::dbExecute(con, read_file("dbimport/sql/upd_db.sql")))

# import non-core
cli::cli_h1("Importing non-core data")
ncore_dir <- file.path(getOption("noas")$TABDIR, "non_core")
DEBUG = FALSE
if(getOption("noas")$IMPORT_DEBUG == "1")
  DEBUG = TRUE
table_ids <- list_folders(ncore_dir, sort = DEBUG)
k <-  lapply(table_ids,
             import_non_core,
             ncore_dir = ncore_dir)

# NOTE: convert these parameters to positional command line arguments?
invisible(DBI::dbExecute(
  con,
  "INSERT INTO versions (id, label, ts, import_completed) VALUES ($1, $2, $3, TRUE)",
  params = list(
    getOption("noas")$IMPORT_ID,
    getOption("noas")$IMPORT_LABEL,
    getOption("noas")$IMPORT_DATE
  ))
)

# end DB transaction
# make db changes permanent and visible to other cons
invisible(DBI::dbCommit(con))
invisible(DBI::dbDisconnect(con))

# declare ended import
cli::cli_h1("import complete")
