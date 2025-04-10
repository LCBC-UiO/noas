#' Read config file
#'
#' The data base has a config.txt
#' file where some settings for the
#' data base is set. This function
#' reads in that file and makes
#' available these settings for use.
#'
#' @return list
read_config <- function() {
  cfg <- list()
  final_cfg <- list()

  # Helper to load key-value pairs from a file
  .load_config_file <- function(file_path) {
    if (!file.exists(file_path)) {
      return(list())
    }
    lines <- readLines(file_path)
    lines <- lines[!grepl("^#", lines)]  # remove comments
    lines <- lines[lines != ""] # remove empty lines
    
    file_cfg <- list()
    for (line in lines) {
      line <- gsub("#.*$", "" , line) # remove comments
      line <- gsub("\ *$", "" , line) # remove trailing spaces
      if (line == "") { # skip empty lines
        next()
      }
      key <- gsub("=.*$", "",  line)
      value_quoted <- gsub("^[^=]*=", "", line)
      # Use tryCatch for safer parsing, defaulting to NA on error
      value <- tryCatch({
        as.character(parse(text=value_quoted))
      }, error = function(e) {
        warning(paste("Error parsing value for key:", key, "in file:", file_path, ". Value:", value_quoted, "Error:", e$message))
        NA_character_
      })
      file_cfg[[key]] <- value
    }
    return(file_cfg)
  }

  # Load defaults first
  cfg_default <- .load_config_file("config_default.txt")
  cfg <- cfg_default

  # Override with user config file if it exists
  cfg_user <- .load_config_file("config.txt")
  for (key in names(cfg_user)) {
    cfg[[key]] <- cfg_user[[key]]
  }

  # Populate final_cfg, prioritizing environment variables
  for (key in names(cfg)) {
    nkey <- sprintf("NOAS_%s", key)
    env_var_value <- Sys.getenv(nkey)
    
    if (env_var_value != "") {
      # TODO: Consider type conversion if env vars shouldn't always be strings
      final_cfg[[key]] <- env_var_value
    } else {
      final_cfg[[key]] <- cfg[[key]]
    }
  }
  
  # Explicitly add/override crucial vars directly from environment 
  # Use defaults if environment variable is not set or empty
  final_cfg[["TABDIR"]] <- Sys.getenv("NOAS_TABDIR", "/data") # Default to /data
  final_cfg[["IMPORT_DEBUG"]] <- Sys.getenv("NOAS_IMPORT_DEBUG", "0") # Default to "0"
  
  # Helper to set default value if key is missing or empty/NA in final_cfg
  .set_default <- function(config_list, key, default) {
    if (!key %in% names(config_list) || is.null(config_list[[key]]) || config_list[[key]] == "" || is.na(config_list[[key]])) {
      config_list[[key]] <- default
    }
    config_list
  }
  
  curr_date <- date()
  # Apply defaults only if not set by files or environment variables
  final_cfg <- .set_default(final_cfg, "IMPORT_LABEL", "unnamed version")
  final_cfg <- .set_default(final_cfg, "IMPORT_DATE",  curr_date)
  final_cfg <- .set_default(final_cfg, "IMPORT_ID", sprintf("undefined (%s)", as.character(curr_date)))
  
  return(final_cfg)
}

#' Read file as string/character
#'
#' @param path path to file
#'
#' @return character
read_file <- function(path){
  readChar(path, file.info(path)$size)
}

#' Read noas data table
#'
#' @param path path to file
#' @param ... other arguments to \code{read.table}
#'
#' @return data.frame
read_noas_table <- function(path, ...){
  read.table(path, header = TRUE, sep = "\t",
             comment.char = "", fill = FALSE,
             colClasses = "character",
             blank.lines.skip	= FALSE,
             check.names = FALSE,
             quote = "", dec = ".",
             ...)
}

fail_if <- function(expr, ..., .envir = parent.frame()){
  if(expr){
    cli::cli_abort(..., call. = FALSE, .envir = .envir)
  }
}

#' Check if tsv's are NOAS compatible
#'
#' Runs checks on a set of tsv files
#' together, to make sure they adhere
#' to NOAS data standards
#'
#' Checks run:
#' \itemize{
#'   \item{All files end with \code{tsv}}
#'   \item{All files have same number of columns}
#'   \item{All files have same column order}
#'   \item{No data rows with only <NA>}
#'   \item{No key duplications}
#' }
#'
#' @param tsv_list character vector of tsv files
#' @param tsv_dir path to containing directory
check_tsvs <- function(tsv_list, tsv_dir){
  # Read debug setting once
  is_debug <- Sys.getenv("NOAS_IMPORT_DEBUG", "0") == "1"
  
  if(is_debug){
    cli::cli_alert_info("DEBUG: Entering check_tsvs for directory: {.path {tsv_dir}}")
    cli::cli_alert_info("DEBUG: Files to check: {.file {tsv_list}}")
  }
  
  # If no files are passed for this prefix, do nothing
  if(length(tsv_list) == 0){
    if(is_debug) cli::cli_alert_info("DEBUG: No files found, exiting check_tsvs.")
    return(invisible(NULL))
  }
  
  is_tsv <- grepl("tsv$", tsv_list)
  fail_if(!all(is_tsv),
          "Table not ending in 'tsv':\n",
          paste(tsv_list[!is_tsv], collapse=" ")
  )
  
  # column names and order match (across all files)
  # Use tryCatch for safer file reading, especially for headers
  read_header_safely <- function(file_path) {
    tryCatch({
      names(read_noas_table(file_path, nrow = 1))
    }, error = function(e) {
      cli::cli_alert_danger("Error reading header for file: {.path {file_path}}")
      cli::cli_alert_danger(paste("Error message:", e$message))
      # Return NULL or an empty list to indicate failure, 
      # allowing the check logic below to potentially fail more gracefully or be adapted
      NULL 
    })
  }
  
  file_ref_path <- file.path(tsv_dir, tsv_list[1])
  file_head_ref <- read_header_safely(file_ref_path)
  
  fail_if(is.null(file_head_ref), "Failed to read header for reference file: {.path {file_ref_path}}")
  
  if(is_debug){
      cli::cli_alert_info("DEBUG: Reference file: {.path {file_ref_path}}")
      # Evaluate header pasting outside cli string
      ref_header_str <- paste(file_head_ref, collapse=", ")
      cli::cli_alert_info("DEBUG: Reference header ({length(file_head_ref)} cols): {ref_header_str}")
  }
  
  # Only check subsequent files if there are more than one
  if (length(tsv_list) > 1) {
    for(f in tsv_list[-1]){
      file_cur_path <- file.path(tsv_dir, f)
      file_head_cur <- read_header_safely(file_cur_path)
      
      fail_if(is.null(file_head_cur), "Failed to read header for file: {.path {file_cur_path}}")
      
      if(is_debug){
          cli::cli_alert_info("DEBUG: Comparing file: {.path {file_cur_path}}")
          # Evaluate header pasting outside cli string
          cur_header_str <- paste(file_head_cur, collapse=", ")
          cli::cli_alert_info("DEBUG: Current header ({length(file_head_cur)} cols): {cur_header_str}")
      }
      
      # Fail on differing column length and name/order
      fail_if(length(file_head_ref) != length(file_head_cur),
              c("Differing number of columns in files:",
                "Reference ({length(file_head_ref)}): {.path {file_ref_path}}",
                "Current ({length(file_head_cur)}): {.path {file_cur_path}}")
      )
      fail_if(!all(file_head_ref == file_head_cur),
              c("Files do not have equally named/ordered columns:",
                "Reference: {.path {file_ref_path}}",
                "Current: {.path {file_cur_path}}",
                "Ref Header: {paste(file_head_ref, collapse=", ")}",
                "Cur Header: {paste(file_head_cur, collapse=", ")}")
      )
    }
  }
  
  # Moved the actual data reading inside the loop/check to avoid reading all files if headers differ
  # Also, only perform data checks (NA, dup keys) for non-core tables
  if(basename(tsv_dir) != "core"){
    if(is_debug) cli::cli_alert_info("DEBUG: Performing data checks (NA, duplicate keys) for non-core directory: {.path {tsv_dir}}")
    
    all_file_data <- list()
    for(f in tsv_list) {
      file_path <- file.path(tsv_dir, f)
      if(is_debug) cli::cli_alert_info("DEBUG: Reading data file: {.path {file_path}}")
      # Use tryCatch for full file reading as well
      current_data <- tryCatch({
        read_noas_table(file_path)
      }, error = function(e) {
          cli::cli_alert_danger("Error reading data for file: {.path {file_path}}")
          cli::cli_alert_danger(paste("Error message:", e$message))
          NULL # Return NULL on error
      })
      
      fail_if(is.null(current_data), "Failed to read data for file: {.path {file_path}}")
      all_file_data[[f]] <- current_data
    }
    
    # Combine data only after successfully reading all files in the list
    dt <- do.call(rbind, all_file_data)
    keys <- key_cols(tsv_dir)
    check_na(dt, keys)
    check_dup_keys(dt, keys)
  }
  if(is_debug) cli::cli_alert_info("DEBUG: Exiting check_tsvs for directory: {.path {tsv_dir}}")
}

check_na <- function(data, keys){
  x <- data[, keys * -1]
  is_na <- if(is.null(dim(x))){
    is.na(x)
  }else{
    apply(x, 1, function(x) all(is.na(x)))
  }
  fail_if(
    any(is_na),
    c("Some data have only <NA> rows in non-key columns.",
    i = "These should be deleted:",
    printdf(data[which(is_na), keys]))
  )
}

check_dup_keys <- function(data, keys){
  x <- data[, keys]
  is_na <- duplicated(x)
  fail_if(
    any(is_na),
    c("Duplicated keys in file.",
      i = "These must be fixed:",
      printdf(x[which(is_na), ])
    )
  )
}


printdf <- function(data){
  text <- jsonlite::toJSON(
    data,
    pretty = TRUE,
    na = "string",
    null = "null")
  text <- strsplit(text, "\n")[[1]]
  text <- gsub("\\}", "}}", text)
  gsub("\\{", "{{", text)
}

key_cols <- function(dir){
  type <- jsonlite::read_json(file.path(dir, "_noas.json"))$table_type
  switch(type,
         "longitudinal" = 1:3,
         "cross-sectional" = 1,
         "repeated" = 1:4
  )
}

list_folders <- function(directory, sort = FALSE){
  folders <- list.dirs(directory, recursive = FALSE, full.names = TRUE)
  if(sort){
    modtimes <- sapply(folders, function(folder) {
      files <- list.files(path = folder, full.names = TRUE)
      ifelse (length(files) > 0,
        max(file.info(files)$mtime),
        NA
      )
    })
    folders <- folders[order(modtimes, decreasing = TRUE)]
  }
  return(basename(folders))
}

import_non_core <- function(table_id, ncore_dir){
  cli::cli_h3(table_id)
  metadata_j <- NULL
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
  pattern <- glob2rx("^_*tsv$")
  if(any(grepl(pattern, cur_file_list))){
    ignore_files <- cur_file_list[grepl(pattern, cur_file_list)]
    cli::cli_alert_warning(paste("ignoring", ignore_files))
    cur_file_list <- setdiff(cur_file_list, ignore_files)
  }
  if(!length(cur_file_list) > 0){
    cli::cli_alert_danger("No tsv files to import.")
  }else{
    check_tsvs(cur_file_list, table_dir_cur)
    for(f_tsv in cur_file_list){
      # read table
      noas_table_data <- read_noas_table(file.path(table_dir_cur, f_tsv))
      # push as temp table to db
      table_id_tmp <- sprintf("tmp_%s", table_id)
      DBI::dbWriteTable(
        con,
        table_id_tmp,
        noas_table_data,
        row.name = FALSE
      )
      # import table to noas
      DBI::dbExecute(
        con,
        "select import_table($1, $2, $3, $4)",
        params = list(
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
    }# end tsv
    if (!is.null(metadata_j)) {
      meta <- cli::cli_progress_step("meta-data", spinner = TRUE)
      DBI::dbExecute(
        con,
        "select import_metadata($1, $2)",
        params = list(
          table_id,
          metadata_j
        )
      )
      meta <- cli::cli_progress_update(id = meta)
    }
  } # end if
}

