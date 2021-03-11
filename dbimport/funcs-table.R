source("dbimport/funcs-utils.R", echo = FALSE)
source("dbimport/funcs-printouts.R", echo = FALSE)
source("dbimport/funcs-metadata.R", echo = FALSE)
source("dbimport/funcs-validate.R", echo = FALSE)

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
#' @param table_dir name to give the table
#' @param template_path path to the SQL template to apply
#' @param ... additional arguments to \code{\link[DBI]{dbWriteTable}}
insert_table <- function(x,
                         con,
                         type,
                         table_dir,
                         file_name,
                         visit_id_column = NULL,
                         ...){
  stopifnot(is.data.frame(x))
  stopifnot(nrow(x) > 0)

  table_name <- basename(table_dir)
  template_path <- sql_templates(type)

  dbtab <- sprintf("%s_%s", type, table_name)
  n_before <- get_rows(con, dbtab)

  x$`_noas_data_source` <- file.path(table_name, basename(file_name))

  tryCatch({
    k <- DBI::dbWriteTable(
      con,
      sprintf("tmp_%s", table_name),
      x,
      row.name = FALSE,
      ...
    )

    if(k == FALSE) stop("\ntmp table not initiated\n")

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
    sprintf("drop table if exists tmp_%s;", table_name)
  )
  )
  
  n_after <- get_rows(con, dbtab)
  n <- sprintf("(%5d/%5d omitted)", abs(n_after-n_before-nrow(x)), nrow(x))

  cat_table_success(k, paste(type, table_name, basename(file_name), n, sep="\t"))
  invisible(k)
}


get_data <- function(table_dir, key_vars) {

  ffiles <- list.files(table_dir, "tsv$", full.names = TRUE)

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

#' Read in sql file
#'
#' @param path path to sql file
#'
#' @return character
#' @export
read_sql <- function(path, ...){
  readChar(path, file.info(path)$size, ...)
}


# populate functions ----
populate_core <- function(con){
  if(is.null(con)){
    stop("Database connection not supplied, table not populated.")
  }

  # Add all core tables
  j <- lapply(c("subjects", "projects", "waves", "visits"),
              add_core_table, con = con)
}

populate_tables <- function(con){
  if(is.null(con)){
    stop("Database connection not supplied, table not populated.", call. = FALSE)
  }

  db_dir <- file.path(read_config()$TABDIR,
                      "non_core")

  # Find top-level folders
  tabs <- list.dirs(db_dir, recursive = FALSE, full.names = TRUE)
  tabs <- normalizePath(tabs)
  tabs <- sapply(tabs, file.mtime)
  tabs <- tabs[rev(order(tabs))]

  # Loop through and populate
  k <- sapply(names(tabs), populate_table, con = con)
}

populate_table <- function(table, con = NULL) {
  cat(basename(table), "\n")

  noas_jsn <- read_noas_json(table)
  
  validate_table(table, noas_jsn)

  if(length(table) > 0){
    
    func <- switch(
      noas_jsn$table_type,
      "longitudinal" = add_long_table,
      "cross-sectional" = add_cross_table,
      "repeated" = add_repeated_table
    )

    # loop through all table .tsv and add
    j <- func(table_dir = table, con = con, noas_jsn = noas_jsn)

  }else{
    stop("There are no tables in", basename(table))
  }
}


# Type specific adds ----
#' Add long table to database
#' 
#' will add a long table to the 
#' database using \code{\link{insert_table_cross}}, 
#' also removing the table name from the 
#' headers for cleaner representation in the 
#' data base.
#'
#' @param table_dir name of the table 
#' @param con database connection
#'
#' @return success of adding, invisible
#' @export
add_cross_table <- function(table_dir, con, ...){
  
  # retrieve the data
  data <- get_data(table_dir, prim_keys()$cross)
  
  # insert data to db
  j <- mapply(insert_table,
              x = data$data,
              file_name = data$files,
              MoreArgs = list(con = con,
                              type = "cross",
                              table_dir = table_dir
              )
  )
  
  # insert meta_data if applicable
  k <- fix_metadata(table_dir, con)
  
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
#' @param table_dir name of the table 
#' @param con database connection
#'
#' @return success of adding, invisible
#' @export
add_long_table <- function(table_dir, con, ...){
  # retrieve the data
  data <- get_data(table_dir, prim_keys()$long)
  
  # insert data to db
  j <- mapply(insert_table,
              x = data$data,
              file_name = data$files,
              MoreArgs = list(con = con,
                              type = "long",
                              table_dir = table_dir
              )
  )
  
  # insert meta_data if applicable
  data <- fix_metadata(table_dir, con)
  
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
#' @param table_dir name of the table 
#' @param con database connection
#'
#' @return success of adding, invisible
#' @export
add_repeated_table <- function(table_dir, con, noas_jsn, ...){
  
  # retrieve the data
  data <- get_data(table_dir, prim_keys()$repeated)
  fourth_key <- sapply(data$data, function(x) names(x)[4])
  fourth_key <- unique(fourth_key)
  
  stopifnot(length(fourth_key) == 1)
  
  # insert data to db
  j <- mapply(insert_table,
              x = data$data,
              file_name = data$files,
              MoreArgs = list(con = con,
                              type = "repeated",
                              table_dir = table_dir,
                              visit_id_column = fourth_key
              )
  )

  # add repeated_group
  if (!is.null(noas_jsn$repeated_group)) {
    sql <- "INSERT into meta_repeated_grps (metatable_id, metacolumn_id, repeated_group) VALUES ($1, $2, $3)"
    params <- list(
      basename(table_dir),
      fourth_key,
      noas_jsn$repeated_group
    )
    if (DBI::dbExecute(con, sql, params=params) != 1) {
      stop(
        sprintf("insert_metadata meta_repeated_grps table=%s field=%s values=(%s,%s,%s)",
          basename(table_dir),
          fourth_key,
          noas_jsn$repeated_group
        )
      )
    }
  }
  # insert meta-data if applicable
  k <- fix_metadata(table_dir, con)
  invisible(j)
}

add_core_table <- function(tab, con){
  
  db_dir <- file.path(read_config()$TABDIR, "core")
  
  filenm <- list.files(db_dir, paste0(tab,".*.tsv"), full.names = TRUE)
  
  .tbl_add <- function(file){
    x <- read_dbtable(file)
    
    n_before <- get_rows(con, tab)
    
    j <- DBI::dbWriteTable(con, tab, x,
                           append = TRUE,
                           row.name = FALSE)
    
    
    n_after <- get_rows(con, tab)
    n <- sprintf("(%5d/%5d omitted)", abs(n_after-n_before-nrow(x)), nrow(x))
    
    cat_table_success(j, paste("core", file, n, sep="\t"))
    invisible(j)
  }
  
  lapply(filenm, .tbl_add)
}

