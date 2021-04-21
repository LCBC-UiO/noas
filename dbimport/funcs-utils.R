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
  cfg <- .set_default(cfg, "IMPORT_ID",  sprintf("undefined (%s)", as.character(curr_date)))
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
             ...)
}

fail_if <- function(expr, ...){
  if(expr){
    stop(..., call. = FALSE)
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
