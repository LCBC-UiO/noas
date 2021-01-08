source("dbimport/funcs-read.R", echo = FALSE)
source("dbimport/funcs-utils.R", echo = FALSE)
source("dbimport/funcs-printouts.R", echo = FALSE)
source("dbimport/funcs-metadata.R", echo = FALSE)

# Insert functions are functions taking a single
# table and placing it in the DB
# Add functions efficiently adds multiple tables
# of the same type. 


# generic table funcs ----
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
#' @param ... additional arguments to \code{\link[DBI]{dbWriteTable}}
insert_table <- function(x, 
                         con, 
                         type,
                         table_name, 
                         file_name, 
                         visit_id_column = NULL,
                         ...){
  stopifnot(is.data.frame(x))
  
  table_name <- gsub("/", "_", table_name)
  template_path <- sql_templates(type)
  
  dbtab <- paste(type, table_name, sep="_")
  n_before <- get_rows(con, dbtab)
  
  tryCatch({
    k <- DBI::dbWriteTable(
      con, 
      paste0("tmp_", table_name), 
      x, 
      row.name = FALSE,
      ...
    )
    
    if(k == FALSE) stop("\ntmp table not initiated\n",
                        call. = FALSE)
    
    template <- read_sql(template_path)
    
    # replace {table_name} with content of table_name
    tmp_template <- gsub("\\{table_name\\}", 
                         table_name, template)
    
    # replace {visit_id_column} with content of visit_id_column
    if(!is.null(visit_id_column)){
      tmp_template <- gsub("\\{visit_id_column\\}", 
                           visit_id_column, tmp_template)
    }
    
    DBI::dbExecute(con, tmp_template)
  },  
  finally = DBI::dbExecute(
    con,
    paste0("drop table if exists tmp_",
           table_name,";")
  )
  )
  
  n_after <- get_rows(con, dbtab)
  n <- sprintf("(%5d|%5d omitted)", abs(n_after-n_before-nrow(x)), nrow(x))
  
  cat_table_success(j, paste(type, table_name, basename(file_name), n, sep="\t"))
  invisible(j)
}


get_data <- function(table_name, db_dir, key_vars) {
  dir <- file.path(db_dir, table_name)
  
  ffiles <- list.files(dir, "tsv$", full.names = TRUE)
  
  # remove tables with "unknown" project, these are for record keeping
  ffiles <- ffiles[!grepl("unknown|NA|00.0", ffiles)]
  
  # Read in all tables
  ft <- lapply(ffiles, read_dbtable)
  
  # Turn all to character
  ft <- lapply(ft, function(x) as.data.frame(lapply(x, as.character), 
                                             stringsAsFactors = FALSE))
  
  # remove table name from headers
  ft <- rename_table_headers(ft, key_vars)
  
  # Alter subject_id and wave_code back to correct type
  ft <- lapply(ft, function(x){
    x$subject_id <- as.integer(x$subject_id)
    
    if("wave_code" %in% names(x))
      x$wave_code <- as.numeric(x$wave_code)
    
    x
  })
  
  return(list(data = ft, files = ffiles))
}


# Type specific adds ----
#' Add long table to database
#' 
#' will add a long table to the 
#' databse using \code{\link{insert_table_cross}}, 
#' also removing the table name from the 
#' headers for cleaner representation in the 
#' data base.
#'
#' @param table_name name of the table 
#' @param con database connection
#' @param db_dir directory for the databse
#'
#' @return success of adding, invisible
#' @export
add_cross_table <- function(table_name, 
                            con, 
                            db_dir){
  
  # retrieve the data
  data <- get_data(table_name, db_dir, c("subject_id"))
  
  # insert data to db
  j <- mapply(insert_table, 
              x = data$data, 
              file_name = data$files,
              MoreArgs = list(con = con, 
                              type = "cross",
                              table_name = table_name
              )
  )
  
  # insert meta_data if applicable
  k <- fix_metadata(data$data, 
                    table_name, 
                    file.path(db_dir, table_name), 
                    con
  )
  
  invisible(j)
}


#' Add long table to database
#' 
#' will add a long table to the 
#' databse using \code{\link{insert_table_long}}, 
#' also removing the table name from the 
#' headers for cleaner representation in the 
#' data base.
#'
#' @param table_name name of the table 
#' @param con database connection
#' @param db_dir directory for the databse
#'
#' @return success of adding, invisible
#' @export
add_long_table <- function(table_name, 
                           con, 
                           db_dir
){
  # retrieve the data
  data <- get_data(table_name, db_dir, c("subject_id",
                                         "project_id", 
                                         "wave_code"))
  
  # insert data to db
  j <- mapply(insert_table, 
              x = data$data, 
              file_name = data$files,
              MoreArgs = list(con = con, 
                              type = "long",
                              table_name = table_name
              )
  )
  
  # insert meta_data if applicable
  data <- fix_metadata(data$data[[1]], 
                       table_name, 
                       file.path(db_dir, table_name), 
                       con
  )
  
  invisible(j)
}


#' Add long table to database
#' 
#' will add a repeated table to the 
#' databse using \code{\link{insert_table_repeated}}, 
#' also removing the table name from the 
#' headers for cleaner representation in the 
#' data base.
#'
#' @param table_name name of the table 
#' @param con database connection
#' @param db_dir directory for the database
#'
#' @return success of adding, invisible
#' @export
add_repeated_table <- function(table_name, 
                               con, 
                               db_dir
){
  
  # retrieve the data
  data <- get_data(table_name, db_dir, c("subject_id",
                                         "project_id", 
                                         "wave_code")
  )
  
  # forth column should be column making row unique
  # might want to change this later
  visit_id_column_old <- names(data$data[[1]])[4]
  visit_id_column_new <- paste0("_", visit_id_column_old)
  # cat(codes()$note(), "Forth column is ", codes()$italic(visit_id_column_old), "\n")
  data$data <- lapply(data$data, 
                      function(x) {
                        names(x) <- gsub(visit_id_column_old, visit_id_column_new, names(x))
                        x
                      })
  
  # insert data to db
  j <- mapply(insert_table, 
              x = data$data, 
              file_name = data$files,
              MoreArgs = list(con = con, 
                              type = "repeated",
                              table_name = table_name,
                              visit_id_column = visit_id_column_new
              )
  )
  
  # insert meta-data if applicable
  k <- fix_metadata(data$data[[1]], 
                    table_name, 
                    file.path(db_dir, table_name), 
                    con
  )
  
  invisible(j)
}

# core tables ----
add_core_tab <- function(tab, db_dir, con){
  
  filenm <- list.files(db_dir, paste0(tab,".*.tsv"), full.names = TRUE)
  
  .tbl_add <- function(file){
    x <- read_dbtable(file)
    
    n_before <- get_rows(con, tab)
    
    j <- DBI::dbWriteTable(con, tab, x, 
                           append = TRUE, row.name = FALSE)
    
    
    n_after <- get_rows(con, tab)
    n <- sprintf("(%5d/%5d omitted)", abs(n_after-n_before-nrow(x)), nrow(x))
    
    cat_table_success(j, paste(file, n, sep="\t"))
    invisible(j)
  }
  
  lapply(filenm, .tbl_add)
}

