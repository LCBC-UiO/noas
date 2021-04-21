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
for(pre in core_pre_seq){
  core_files_cur <- core_files[grep(pre, core_files)]
  core_files <- setdiff(core_files, core_files_cur)  
  
  check_tsvs(core_files_cur, core_dir)
  
  for(f in core_files_cur){
    f_path <- file.path(core_dir, f)
    cat(f_path, "\n")
    DBI::dbWriteTable(
      con, 
      pre, 
      read_noas_table(f_path),
      append = TRUE,
      row.name = FALSE
    )
  }
}
# error if still something in file list after loop
fail_if(length(core_files) > 0, 
        "There are unhandled files in ", core_dir)

# import non-core
ncore_dir <- file.path(getOption("noas")$TABDIR, "non_core")
table_ids <- list.dirs(ncore_dir, recursive = FALSE, full.names = FALSE)
for(table_id in table_ids){
  table_dir_cur <- file.path(ncore_dir, table_id) 
  cur_file_list <- list.files(table_dir_cur)
  fail_if(!"_noas.json" %in% cur_file_list, 
          "There is no _noas.json for table ", table_id)
  noas_j <- read_file(file.path(table_dir_cur, "_noas.json"))
  cur_file_list <- setdiff(cur_file_list, "_noas.json")
  if("_metadata.json" %in% cur_file_list){
    metadata_j <- read_file(file.path(table_dir_cur, "_metadata.json"))
    cur_file_list <- setdiff(cur_file_list, "_metadata.json")
  }
  check_tsvs(cur_file_list, table_dir_cur)
  
  for(f_tsv in cur_file_list){
    f_tsv_path <- file.path(table_dir_cur, f_tsv)
    table_id_tmp <- sprintf("tmp_%s", table_id)
    cat(f_tsv_path, "\n")
    # TOT: make SQL deal with renaming --
    noas_table_data <- read_noas_table(f_tsv_path)
    renam_cols_idx <- which(!names(noas_table_data) %in% c("subject_id", "project_id", "wave_code"))
    names(noas_table_data)[renam_cols_idx] <- paste0("_", names(noas_table_data)[renam_cols_idx])
    # --
    DBI::dbWriteTable(
      con,
      table_id_tmp,
      noas_table_data,
      row.name = FALSE
    )
    DBI::dbExecute(
      con, 
      "select import_table($1, $2, $3, $4)", 
      params=list(
        table_id_tmp,
        table_id,
        noas_j,
        file.path(table_id, f_tsv)
      )
    )
    DBI::dbExecute(
      con,
      sprintf("drop table if exists tmp_%s;", table_id)
    )
  } # end f_tsv
  DBI::dbExecute(
    con, 
    "select import_metadata($1, $2)", 
    params=list(
      table_id,
      metadata_j
    )
  )
} # end table_id


# NOTE: convert these parameters to positional command line arguments?
invisible(DBI::dbExecute(
  con,
  "INSERT INTO versions (id, label, ts, import_completed) VALUES ($1, $2, $3, TRUE)",
  params=list(
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
cat("import complete\n")


