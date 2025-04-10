#!/usr/bin/env Rscript
source('dbimport/funcs-utils.R')

# Set global R options (excluding 'noas' config)
options(
  stringsAsFactors = FALSE,
  warn = 2 # error on warnings
)

# Connect to DB using environment variables
# Ensure .env file provides: DBHOST, DBPORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD
con <- DBI::dbConnect(
  RPostgreSQL::'PostgreSQL'(),
  user     = Sys.getenv("POSTGRES_USER", "dbuser"), # Default matches original
  password = Sys.getenv("POSTGRES_PASSWORD", ""),   # Default empty, but required!
  port     = Sys.getenv("DBPORT", "5432"),        # Default standard pg port
  dbname   = Sys.getenv("POSTGRES_DB", "lcbcdb"),   # Default matches original
  host     = Sys.getenv("DBHOST", "localhost")     # Default localhost
)

# Load import-specific config after connection
import_config <- read_config()

# start atomic transaction, changes in this con won't be visible until the commit
invisible(DBI::dbBegin(con))

# initiate DB
cli::cli_h1("Initializing database")

## suppress NOTICE messages
cli::cli_alert_info("suppressing NOTICE messages")
invisible(DBI::dbExecute(con, "SET client_min_messages = warning;"))

## Delete everything in the database
cli::cli_alert_info("purging database")
invisible(DBI::dbExecute(con, read_file("dbimport/sql/01_purge.sql")))

## Define functions
cli::cli_alert_info("defining functions")
invisible(DBI::dbExecute(con, read_file("dbimport/sql/02_funcs.sql")))

## Create tables
cli::cli_alert_info("creating tables")
invisible(DBI::dbExecute(con, read_file("dbimport/sql/03_table.sql")))

## Create NOAS core data table
cli::cli_alert_info("creating core data table")
invisible(DBI::dbExecute(con, read_file("dbimport/sql/04_corev.sql")))

# Populate database
cli::cli_h1("Populating data base")
cli::cli_h2("Importing core data")

# import core
core_dir <- file.path(import_config$TABDIR, "core") # Should be /data/core
core_pre_seq <- c("projects", "waves", "subjects", "visits")
processed_files <- c() # Keep track of processed files
is_debug <- Sys.getenv("NOAS_IMPORT_DEBUG", "0") == "1"

if(is_debug) {
  cli::cli_alert_info("DEBUG: Core directory path: {.path {core_dir}}")
  # Evaluate list.files outside the cli string to avoid parsing issues
  all_files_debug <- list.files(core_dir)
  cli::cli_alert_info("DEBUG: Listing all files in core_dir directly: {.file {all_files_debug}}")
  project_pattern_debug = '^projects.*\\.tsv$'
  project_files_debug <- list.files(core_dir, pattern=project_pattern_debug)
  cli::cli_alert_info("DEBUG: Testing pattern {.val {project_pattern_debug}} directly: {.file {project_files_debug}}")
}

#   - loop through prefixes (order by sequences needed)
for(pre in core_pre_seq){
  # Construct pattern: starts with prefix, followed by anything, ends with .tsv
  pattern <- sprintf("^%s.*\\.tsv$", pre)
  if(is_debug) cli::cli_alert_info("DEBUG: Searching for pattern {.val {pattern}} in {.path {core_dir}}")
  
  # List files matching the specific pattern for this prefix
  core_files_cur <- list.files(core_dir, pattern = pattern, full.names = FALSE) # Get just filenames

  if(is_debug) cli::cli_alert_info("DEBUG: Found files for pattern {.val {pattern}}: {.file {core_files_cur}}")
  
  # Filter out any files already processed by a previous prefix (unlikely but safe)
  core_files_cur <- setdiff(core_files_cur, processed_files)
  
  # Add currently found files to the processed list
  processed_files <- c(processed_files, core_files_cur)
  
  # Call check_tsvs only if files were found for this prefix
  if (length(core_files_cur) > 0) {
    check_tsvs(core_files_cur, core_dir) # Pass only filenames
    
    # Process the found files
    for(f in core_files_cur){
      cli::cli_progress_step(f)
      DBI::dbWriteTable(
        con,
        pre, # Use the prefix as the table name
        read_noas_table(file.path(core_dir, f)), # Construct full path here
        append = TRUE,
        row.name = FALSE
      )
      cli::cli_progress_done()
    }
  } # No need for an else here, check_tsvs handles empty list logging if debug is on
}

# Check for unprocessed TSV files in the core directory after the loop
all_core_tsvs <- list.files(core_dir, pattern = "\\.tsv$", full.names = FALSE)
unprocessed_files <- setdiff(all_core_tsvs, processed_files)

fail_if(length(unprocessed_files) > 0,
        c("There are unhandled TSV files in {.path {core_dir}}:",
          paste(unprocessed_files, collapse=", "))
)

# update core visits
calcs <- cli::cli_progress_step("Adding visit variables", spinner = TRUE)
invisible(DBI::dbExecute(con, read_file("dbimport/sql/upd_db.sql")))
calcs <- cli::cli_progress_update(id = calcs)

# import non-core
cli::cli_h2("Importing non-core data")
ncore_dir <- file.path(import_config$TABDIR, "non_core")
DEBUG = FALSE
if(import_config$IMPORT_DEBUG == "1")
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
    import_config$IMPORT_ID,
    import_config$IMPORT_LABEL,
    import_config$IMPORT_DATE
  ))
)

# end DB transaction
# make db changes permanent and visible to other cons
invisible(DBI::dbCommit(con))
invisible(DBI::dbDisconnect(con))

# declare ended import
cli::cli_h1("import complete")
