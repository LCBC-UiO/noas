source("dbimport/funcs-read.R", echo = FALSE)
source("dbimport/funcs-utils.R", echo = FALSE)

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
#' @param table_dir table directory path
get_metadata <- function(data, table_dir){
  meta_info <- read_metadata(table_dir)
  
  # Generate some information based on file location
  meta_info$id <- basename(table_dir)
  meta_info$raw_data <- table_dir
  meta_info$table_type <- noas_table_type(table_dir)
  
  return(meta_info)
}

fix_metadata <- function(data, table_dir, con) {

  # get meta-data
  meta_info <- get_metadata(data, table_dir)
  
  # add meta-data
  if (!is.null(meta_info)) {
    j <- insert_metadata(con, meta_info) 
    cat_table_success(j, sprintf("metadata\t%s\tadded\t ", basename(table_dir)))
  }
  
  data
}
