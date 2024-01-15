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
  .add_configs <- function(cfg, fn) {
    lines <- readLines(fn)
    lines <- lines[!grepl("^#", lines)]  # remove comments
    lines <- lines[lines != ""] # remove empty lines
    for (line in lines) {
      line <- gsub("#.*$", "" , line) # remove comments
      line <- gsub("\ *$", "" , line) # remove trailing spaces
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
  cfg <- .set_default(cfg, "IMPORT_ID",
    sprintf("undefined (%s)", as.character(curr_date)))
  cfg
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
  is_tsv <- grepl("tsv$", tsv_list)
  fail_if(!all(is_tsv),
          "Table not ending in 'tsv':\n",
          paste(tsv_list[!is_tsv], collapse=" ")
  )
  # column names and order match (across all files)
  file_data <- lapply(
    file.path(tsv_dir, tsv_list),
    read_noas_table
  )
  names(file_data) <- tsv_list
  file_heads <- lapply(file_data, names)
  names(file_heads) <- tsv_list
  file_ref <- file.path(tsv_dir, tsv_list[1])
  file_head_ref <- names(read_noas_table(file_ref, nrow = 1))
  for(f in tsv_list[-1]){
    file_cur <- file.path(tsv_dir, f)
    file_head <- names(read_noas_table(file_cur, nrow = 1))
    # Fail on differing column length and name/order
    fail_if(length(file_head_ref) != length(file_head),
            "Differing number of columns in files:\n",
            file_cur, file_ref
    )
    fail_if(!all(file_head_ref == file_head),
            "Files do not have equally named columns:\n",
            file_cur, file_ref
    )
  }
  if(basename(tsv_dir) != "core"){
    dt <- do.call(rbind, file_data)
    keys <- key_cols(tsv_dir)
    check_na(dt, keys)
    check_dup_keys(dt, keys)
  }
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
