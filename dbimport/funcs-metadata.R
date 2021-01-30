source("dbimport/funcs-read.R", echo = FALSE)
source("dbimport/funcs-utils.R", echo = FALSE)

# meta data ----
#' Inserts meta-information to the DB
#' 
#' Insert meta-information provided
#' into the meta-information tables
#' in the database.
#' 
#' @param con database connection
#' @param meta_info information from \code{\link{get_metadata}}
insert_metadata <- function(meta_info, con){
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

  ok <- ifelse(DBI::dbExecute(con, sql, params=params) == 1, TRUE, FALSE)
  
  if(all(c(!is.null(meta_info$columns), 
           nrow(meta_info$columns) > 0))){
    j <- alter_cols(meta_info, con)
  }else{
    j <- TRUE
  }
  
  invisible(all(c(ok, j)))
}

alter_cols <- function(meta_info, con){
  sql_tab = sprintf("ALTER TABLE %s_%s", 
                    meta_info$table_type, meta_info$id)
  
  sql_cols <- mapply(
    sprintf, 
    meta_info$columns$id,
    meta_info$columns$type,
    meta_info$columns$id,
    meta_info$columns$type,
    MoreArgs = list(
      # Need the USING part because all columns are imported as string at first
      # https://stackoverflow.com/questions/13170570/change-type-of-varchar-field-to-integer-cannot-be-cast-automatically-to-type-i
      fmt = 'ALTER COLUMN "_%s" TYPE %s USING (_%s::%s)'
    )
  )
  
  sql_cmd <- paste(sql_tab, 
                   paste(sql_cols, collapse = ", "), 
                   ";", sep = " ")
  
  k <- DBI::dbExecute(con, sql_cmd)
  k <- ifelse(k == 1, TRUE, FALSE)
  invisible(k)
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
get_metadata <- function(table_dir){
  meta_info <- read_metadata(table_dir)
  
  return(meta_info)
}

fix_metadata <- function(table_dir, con) {
  
  # get meta-data
  meta_info <- get_metadata(table_dir)
  
  # add meta-data
  j <- insert_metadata(meta_info, con) 
  cat_table_success(j, sprintf("metadata\t%s\tadded\t ", basename(table_dir)))
}
