# Helper functions

#' Read in sql file
#'
#' @param path path to sql file
#'
#' @return character
#' @export
read_sql <- function(path, ...){
  readChar(path, file.info(path)$size, ...)
}



#' Insert table into DB
#' 
#' Initiates a table in the DB, with the prefix "tmp_"
#' checking primary keys, conflicts with existing data,
#' and if all checks pass updates or creates the
#' final table in the DB.
#'
#' @param x data.frame table to add
#' @param con database connection
#' @param table_name name to give the table
#' @param template_path path to the SQL template to apply
#' @param ... additional arguments to \code{\link{DBI::dbWriteTable}}
insert_table <- function(x, 
                         con, 
                         table_name, 
                         template_path,
                         ...){
  stopifnot(is.data.frame(x))
  
  tryCatch({
    k <- DBI::dbWriteTable(
      con, 
      paste0("tmp_", table_name), 
      x, 
      row.name = FALSE,
      ...
    )
    
    if(k == FALSE) stop("tmp table not initiated",
                        call. = FALSE)
    
    template <- read_sql(template_path)
    tmp_template <- gsub("\\{table_name\\}", 
                         table_name, template)
    
    
    DBI::dbExecute(con, tmp_template)
  },  
  finally = DBI::dbExecute(
    con,
    paste0("drop table if exists tmp_",
           table_name,";")
  )
  )
  
  cat("Table added sucessfully")
}


#' Insert lognitudinal data to DB
#' 
#' Calls insert_table with some presets
#' to add longitudinal data in an
#' easy way to the DB.
#'
#' @inheritParams insert_table
insert_table_long <- function(x, con, 
                              table_name){
  
  insert_table(x, con, table_name,
               template = "sql/insert_long_table.sql",
               #append = TRUE,
               temporary = TRUE,
               overwrite = TRUE
  )
  
}

submit_long_table <- function(x, cols, predicate, table_name){
  x <- dplyr::select(x, 
                     subject_id,
                     project_id,
                     wave_code,
                     {{cols}})
  x <-  dplyr::filter(x, {{predicate}})
  x <-  dplyr::rename_all(x, tolower)
  x <-  dplyr::distinct(x)
  insert_table_long(x, con, table_name)
}


moasdb_connect <- function(){
  DBI::dbConnect(RPostgreSQL::'PostgreSQL'(), #":memory:",
                 user="dbuser", 
                 dbname="lcbcdb", 
                 host="localhost")
}

read_dbtable <- function(file){
  read.table(file, header = TRUE, sep = "\t", 
                   stringsAsFactors = FALSE)
}