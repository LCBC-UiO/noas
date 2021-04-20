#!/usr/bin/env Rscript

#' Read config file
#' 
#' The data base has a config.txt
#' file where some settings for the
#' data base is set. This function
#' reads in that file and makes
#' available these settings for use.
#'
#' @return list
#' @export
read_config <- function() {
  cfg <- list()
  .add_configs <- function(cfg, fn) {
    lines <- readLines(fn)
    
    # remove comments
    lines <- lines[!grepl("^#", lines)]
    # remove empty lines
    lines <- lines[lines != ""]
    
    for (line in lines) {
      line  <- gsub("#.*$", "" , line) # remove comments
      line  <- gsub("\ *$", "" , line) # remove trailing spaces
      if (line == "") { # skip empy lines
        next()
      }
      key <- gsub("=.*$", "",  line)
      value_quoted <- gsub("^[^=]*=", "", line)
      value <- as.character(parse(text=value_quoted))
      cfg[key] <- value
    }
    return(cfg)
  }
  cfg <- .add_configs(cfg, "config_default.txt")
  if (file.exists("config.txt")) {
    cfg <- .add_configs(cfg, "config.txt")
  }
  # override with any existing NOAS_XXX env variables
  for (key in names(cfg)) {
    nkey <- sprintf("NOAS_%s", key)
    v <- Sys.getenv(nkey)
    # only works for non-empty env vars
    if (v != "") {
      cfg[key] <- v
    }
  }
  
  .set_default <- function(cfg, key, default){
    if(cfg[key] == "") cfg[key] <- default
    cfg
  }
  
  curr_date <- date()
  cfg <- .set_default(cfg, "IMPORT_LABEL", "unnamed version")
  cfg <- .set_default(cfg, "IMPORT_DATE",  curr_date)
  cfg <- .set_default(cfg, "IMPORT_ID",  sprintf("undefined (%s)", as.character(curr_date)))
  
  return(cfg)
}

read_file <- function(path){
  readChar(path, file.info(path)$size)
}

read_noas_table <- function(path, ...){
  read.table(path, header = TRUE, sep = "\t", 
             comment.char = "", fill = FALSE, 
             colClasses = "character", 
             blank.lines.skip	= FALSE,
             check.names = FALSE,
             ...)
}

fail_if <- function(expr, ...){
  if(expr){
    stop(..., call. = FALSE)
  }
}

check_tsvs <- function(tsv_list, tsv_dir){
  is_tsv <- grepl("tsv$", tsv_list)
  fail_if(!all(is_tsv), 
          "Table not ending in 'tsv':\n", 
          paste(tsv_list[!is_tsv], collapse=" ")
  )
  # column names and order match (across all files)
  file_heads <- lapply(file.path(tsv_dir, tsv_list), function(x){
    names(read_noas_table(x, nrow = 1))
  })
  names(file_heads) <- tsv_list
  file_ref <- file.path(tsv_dir, tsv_list[1])
  file_head_ref <- names(read_noas_table(file_ref, nrow = 1))
  for(f in tsv_list[-1]){
    file_cur <- file.path(tsv_dir, f)
    file_head <- names(read_noas_table(file_cur, nrow = 1))
    # Fail on differing column length and name/order
    fail_if(length(file_head_ref) != length(file_head),
            "Differing number of columns in files:\n",
            file_cur, " ", file_ref
    )
    fail_if(!all(file_head_ref == file_head),
            "Files do not have equally names columns:\n",
            file_cur, " ", file_ref
    )
  }
}

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
    noas_table_data <- read_noas_table(f_tsv_path)
    renam_cols_idx <- which(!names(noas_table_data) %in% c("subject_id", "project_id", "wave_code"))
    names(noas_table_data)[renam_cols_idx] <- paste0("_", names(noas_table_data)[renam_cols_idx])
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


