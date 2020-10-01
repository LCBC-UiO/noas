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
                         table_name, 
                         visit_id_column = NULL,
                         template_path,
                         ...){
  stopifnot(is.data.frame(x))
  
  table_name <- gsub("/", "_", table_name)
  
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
}


get_data <- function(table_name, db_dir, key_vars, cat_type = "ascii") {
  cat(codes(cat_type)$bold("\n---", table_name, "---\n")) 
  
  dir <- file.path(db_dir, table_name)
  
  ffiles <- list.files(dir, "tsv$", full.names = TRUE)
  
  # remove tables with "unknown" project, these are for record keeping
  ffiles <- ffiles[!grepl("unknown|NA|00.0", ffiles)]
  
  # Read in all tables
  ft <- lapply(ffiles, read_dbtable)

  # Turn all to character
  ft <- lapply(ft, function(x) as.data.frame(lapply(x, as.character)))
  
  # remove table name from headers
  ft <- rename_table_headers(ft, key_vars)
  
  # retrieve meta-data information
  meta <- get_metadata(ft[[1]], table_name, dir)$columns
  
  # assign column types from metadata if they are specified
  if(!is.null(meta$id)){
    meta$id <- fix_names(meta$id)
    meta$func <- type_2_rclass(meta$type)
    
    if(length(meta$func) > 0){
      # match files to assure correct assigning
      meta <- meta[meta$id %in% names(ft[[1]]), ]
      
      # Apply column type change
      ft <- lapply(ft, change_col_type, meta$id, meta$func)
    }
  }else{
    meta$id <- NULL
  }
  
  # Alter subject_id and wave_code back to correct type
  ft <- lapply(ft, function(x){
    x$subject_id <- as.integer(x$subject_id)
    
    if("wave_code" %in% names(x))
      x$wave_code <- as.numeric(x$wave_code)
    
    x
  })
  
  
  return(list(data = ft, files = ffiles))
}


# cross tables ----
#' Insert cross data to DB
#' 
#' Calls insert_table with some presets
#' to add longitudinal data in an
#' easy way to the DB.
#'
#' @param x data.frame table to add
#' @param con database connection
#' @param table_name name to give the table
#' @param orig_name file name of originating file
#' @param cat_type character. either ascii or unicode (no embelishment)
insert_table_cross <- function(x, 
                               con, 
                               table_name, 
                               orig_name = table_name,
                               cat_type = "ascii"){
  
  j <- insert_table(x, con, table_name,
                    template = "dbimport/sql/insert_cross_table.sql",
                    #append = TRUE,
                    temporary = TRUE,
                    overwrite = TRUE
  )
  
  cat_table_success(j, orig_name, cat_type)
  invisible(j)
}


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
#' @param cat_type character. either ascii or unicode (no embelishment)
#'
#' @return success of adding, invisible
#' @export
add_cross_table <- function(table_name, 
                            con, 
                            db_dir,
                            cat_type = "ascii"){
  
  
  # retrieve the data
  data <- get_data(table_name, db_dir, c("subject_id"), cat_type)
  
  # insert data to db
  j <- mapply(insert_table_cross, 
              x = data$data, 
              orig_name = data$files,
              MoreArgs = list(con = con, 
                              table_name = table_name,
                              cat_type = cat_type)
  )
  
  # insert meta_data if applicable
  k <- fix_metadata(data$data, 
                    table_name, 
                    file.path(db_dir, table_name), 
                    con, 
                    cat_type = cat_type)
  
  
  invisible(j)
}


# long tables ----
#' Insert lognitudinal data to DB
#' 
#' Calls insert_table with some presets
#' to add longitudinal data in an
#' easy way to the DB.
#'
#' @param x data.frame table to add
#' @param con database connection
#' @param table_name name to give the table
#' @param orig_name file name of originating file
#' @param cat_type character. either ascii or unicode (no embelishment)
insert_table_long <- function(x, 
                              con, 
                              table_name, 
                              orig_name = table_name,
                              cat_type = "ascii"){
  
  j <- insert_table(x, con, table_name,
                    template = "dbimport/sql/insert_long_table.sql",
                    #append = TRUE,
                    temporary = TRUE,
                    overwrite = TRUE
  )
  
  cat_table_success(j, orig_name, cat_type)
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
                           db_dir, 
                           cat_type = "ascii"){
  # retrieve the data
  data <- get_data(table_name, db_dir, c("subject_id",
                                         "project_id", 
                                         "wave_code"),
                   cat_type = cat_type)
  
  # insert data to db
  j <- mapply(insert_table_long, 
              x = data$data, 
              orig_name = data$files,
              MoreArgs = list(con = con, 
                              table_name = table_name,
                              cat_type = cat_type)
  )
  
  # insert meta_data if applicable
  data <- fix_metadata(data$data[[1]], 
                       table_name, 
                       file.path(db_dir, table_name), 
                       con, 
                       cat_type = cat_type)
  
  invisible(j)
}


# repeated tables ----
#' Insert repeated data to DB
#' 
#' Calls insert_table with some presets
#' to add repeated data in an
#' easy way to the DB.
#'
#' @param x data.frame table to add
#' @param con database connection
#' @param table_name name to give the table
#' @param orig_name file name of originating file
#' @param cat_type character. either ascii or unicode (no embelishment)
insert_table_repeated <- function(x, 
                                  con, 
                                  table_name, 
                                  visit_id_column,
                                  orig_name = table_name,
                                  cat_type = "ascii"){
  
  j <- insert_table(x, con, 
                    table_name,
                    visit_id_column,
                    template = "dbimport/sql/insert_repeated_table.sql",
                    #append = TRUE,
                    temporary = TRUE,
                    overwrite = TRUE
  )
  
  cat_table_success(j, orig_name, cat_type)
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
#' @param cat_type character. either ascii or unicode (no embelishment)
#'
#' @return success of adding, invisible
#' @export
add_repeated_table <- function(table_name, 
                               con, 
                               db_dir,
                               cat_type = "ascii"){
  
  # retrieve the data
  data <- get_data(table_name, db_dir, c("subject_id",
                                         "project_id", 
                                         "wave_code"),
                   cat_type = cat_type)

  # forth column should be column making row unique
  # might want to change this later
  visit_id_column_old <- names(data$data[[1]])[4]
  visit_id_column_new <- paste0("_", visit_id_column_old)
  # cat(codes(cat_type)$note(), "Forth column is ", codes(cat_type)$italic(visit_id_column_old), "\n")
  data$data <- lapply(data$data, 
                      function(x) {
                        names(x) <- gsub(visit_id_column_old, visit_id_column_new, names(x))
                        x
                      })
  
  # insert data to db
  j <- mapply(insert_table_repeated, 
              x = data$data, 
              orig_name = data$files,
              MoreArgs = list(con = con, 
                              table_name = table_name,
                              visit_id_column = visit_id_column_new,
                              cat_type = cat_type)
  )
  
  # insert meta-data if applicable
  k <- fix_metadata(data$data[[1]], 
                    table_name, 
                    file.path(db_dir, table_name), 
                    con, 
                    cat_type = cat_type)
  
  invisible(j)
}

# core tables ----
add_core_tab <- function(tab, db_dir, con, cat_type = "ascii"){
  filenm <- list.files(db_dir, paste0(tab,".tsv"), full.names = TRUE)
  dt <- read_dbtable(filenm)
  j <- DBI::dbWriteTable(con, tab, dt, 
                         append = TRUE, row.name = FALSE)
  
  cat_table_success(j, tab, cat_type)
  invisible(j)
}

