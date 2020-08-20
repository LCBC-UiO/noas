# read functions ----
#' Read database table
#' 
#' Convenience function to easily read 
#' db tables without needing to set
#' extra arguments
#'
#' @param path path to table
#' @param ... other arguments to read.table()
#' @return data.frame
#' @export
read_dbtable <- function(path, ...){
  read.table(text = readLines(path, warn = FALSE), 
             header = TRUE,
             sep = "\t", 
             stringsAsFactors = FALSE, 
             ...)
}


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
  return(cfg)
}


#' Read in sql file
#'
#' @param path path to sql file
#'
#' @return character
#' @export
read_sql <- function(path, ...){
  readChar(path, file.info(path)$size, ...)
}


#' Read in _metadata.json
#'
#' @param dirpath dir where _metadata.json lives
read_metadata <- function(dirpath){
  
  ffile <- file.path(dirpath, "_metadata.json")
  if(file.exists(ffile)){
    meta <- jsonlite::read_json(ffile, 
                                simplifyVector = TRUE)
    return(meta)
  }else(
    return(NULL)
  )
}