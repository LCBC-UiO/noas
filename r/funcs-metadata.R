source("r/funcs-read.R", echo = FALSE)
source("r/funcs-utils.R", echo = FALSE)

# meta data ----
#' Inserts meta-information to the DB
#' 
#' Inserte meta-information provided
#' into the meta-information tables
#' in the database.
#' 
#' @param con database connection
#' @param meta_info information from \code{\link{get_metadata}}
insert_metadata <- function(con, 
                            meta_info){
  sql = paste(
    "UPDATE metatables",
    "SET title = $1",
    # workaround for 'NULL' (text) being inserted
    #   force NULL when input is 'NULL'
    #   https://github.com/r-dbi/RPostgres/issues/95
    ", category = NULLIF($2, 'NULL')::text", 
    "WHERE id = $3"
  )
  
  params <- list(
    meta_info$title,
    meta_info$category,
    meta_info$id
  )
  
  DBI::dbExecute(con, sql, params=params)
  invisible(TRUE)
}


#' Get meta-data information
#' 
#' Based both on file location, and
#' any information in the _metadata.json
#' file, will generate a list for adding
#' meta-information to the data-base.
#'
#' @param data data to base missing information on
#' @param table_name name of the table
#' @param dirpath directory containing raw data
get_metadata <- function(data, table_name, dirpath){
  meta_info <- read_metadata(dirpath)
  
  # if there is no meta-data, do nothing
  # rest is done by the sql commands
  if(is.null(meta_info)){
    return(NULL)
  }
  
  dir_split <- strsplit(dirpath, "/")[[1]]
  
  # Generate some information based on file location
  meta_info$id <- dir_split[length(dir_split)]
  meta_info$raw_data <- dirpath
  meta_info$table_type <- table_types()[table_types() %in% dir_split]
  
  return(meta_info)
}

#' @param cat_type character. either ascii or unicode (no embelishment)
fix_metadata <- function(data, table_name, dir, con, cat_type = "ascii") {
  
  # get meta-data
  meta_info <- get_metadata(data, table_name, dir)
  
  # add meta-data
  if (!is.null(meta_info)) {
    j <- insert_metadata(con, meta_info)
    cat_table_success(j, sprintf("%s metadata added", table_name), cat_type)
  }
  
  data
}
