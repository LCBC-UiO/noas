# Helper functions ----

#' Connect to the DB through R
#'
#' @return PostgreSQL connection
#' @export
moasdb_connect <- function(){
  cfg <- read_config()
  DBI::dbConnect(RPostgreSQL::'PostgreSQL'(), #":memory:",
                 user=cfg$DBUSER, 
                 port=cfg$DBPORT,
                 dbname=cfg$DBNAME, 
                 host=cfg$DBHOST)
}

#' wrap string in character
#' 
#' particularly made to wrap strings in
#' single quotation marks for input to sql
#'
#' @param string caracter
#' @param wrap wrapping character
#'
#' @export
wrap_string <- function(string, wrap = "'"){
  paste0(wrap, string, wrap, collapse = "")
}

#' Camel case a string
#' 
#' make a character separated string
#' to camel case
#'
#' @param string character
#' @param sep separator
camel_case <- function(string, sep = "_"){
  tmp <- strsplit(string, "_")[[1]]
  tmp <- strsplit(tmp, "")
  tmp <- lapply(tmp, function(x) {
    x[1] <- toupper(x[1]); paste0(x, collapse="")
  })
  
  paste0(unlist(tmp), collapse=" ")
}

#' Data base table types
#' 
#' convenience lookup for 
#' types of tables in the data base
table_types <- function(){
  c("core", "cross", "long", "repeated")
}

#' Print out table adding success
#'
#' @param success logical vector for successes
#' @param names charatcer vector of equal length as \code{success}
#'
#' @return
#' @export
#'
#' @examples
#' log_vect <- c(TRUE, TRUE, FALSE)
#' log_name <- c("tab1", "tab2", "tab3")
#' cat_table_success("tables added", log_vect, log_name)
cat_table_success <- function(success, names){
  
  if(length(success) != length(names))
    stop("success and names are not of equal length", call. = FALSE)
  
  if(length(success) == 0){
    cat(crayon::yellow("\U0021"), "no tables added")
  }else{
    
    # if success is TRUE or 0 (adding to existing tables),
    # return green checkmark, else return red x
    j <- lapply(success, function(x) ifelse(x | x == 0, 
                                            crayon::green("\U2713"), 
                                            crayon::red("\U10102")))
    j <- unlist(j)
    
    j <- paste(j, names, sep=" ")
    cat(j)
  }
  cat("\n")
}

cat_add_type <- function(type) {
  cat(crayon::magenta("\n\U25C6"),
      crayon::bold("Adding", type, "tables"), 
      crayon::magenta("\U25C6"))
}

#' Rename headers
#'
#' checks and renames a table header
#' if it has the exact same name as the 
#' table it self. 
#' 
#' @param ft data
#' @param table_name tale name
rename_table_headers <- function(ft, table_name){
  
  # if a column has the same name as the table_name
  # do a small renaming to allow it to happen
  if(table_name %in% names(ft[[1]])){
    idx <- which(names(ft[[1]]) %in% table_name)
    new <- paste(table_name, table_name, sep="_")
    
    cat(crayon::yellow("!"), "Column name same as table name.",
        crayon::yellow("\n!"), "Renaming column", crayon::italic(table_name), "to", 
        crayon::italic(paste(table_name, table_name, sep = "_")),
        "\n")
    
    ft <- lapply(ft, dplyr::rename_all, 
                 .funs = function(x) gsub(paste0("^", table_name, "$"), new, x))
  }
  
  # take away table name from column headers
  ft <- lapply(ft, dplyr::rename_all, 
               .funs = function(x) gsub(paste0("^", table_name), "", x))
  
  ft
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
#' @param ... additional arguments to \code{\link[DBI]{dbWriteTable}}
insert_table <- function(x, 
                         con, 
                         table_name, 
                         visit_id_column = NULL,
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
  sql = paste0(
    "UPDATE metatables ",
    "SET title = $1 ",
    # workaround for 'NULL' (text) being inserted
    #   force NULL when input is 'NULL'
    #   https://github.com/r-dbi/RPostgres/issues/95
    ", category = NULLIF($2, 'NULL')::text ", 
    "WHERE id = $3",
    sep=""
  )
  params <- list(
    meta_info$title,
    meta_info$category,
    meta_info$id
  )
  DBI::dbExecute(con, sql, params=params)
  return(TRUE)
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
  if(is.null(meta_info)){
    return(NULL)
  }
  
  dir_split <- strsplit(dirpath, "/")[[1]]
  
  # Generate som information based on file location
  meta_info$id <- dir_split[length(dir_split)]
  meta_info$raw_data <- dirpath
  
  type <- table_types()[table_types() %in% dir_split]
  meta_info$table_type <- switch(type,
                            "long" = "longitudinal",
                            "cross" = "cross-sectional", 
                            "core" = "core",
                            "repeated" = "repeated within visit")
  

  
  # If no column specification in meta-data
  if(is.null(meta_info$columns)){
    
    meta_info$columns <- lapply(4:ncol(data), 
                                function(x) 
                                  list(class = "text",
                                       title = camel_case(paste0(table_name, names(data)[x])),
                                       id = names(data)[x],
                                       idx = x-3)
    )
    names(meta_info$columns) <- paste0(table_name, names(data[-1:-3]))
  }
  
  return(meta_info)
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
insert_table_cross <- function(x, 
                               con, 
                               table_name, 
                               orig_name = table_name){
  
  j <- insert_table(x, con, table_name,
                    template = "sql/insert_cross_table.sql",
                    #append = TRUE,
                    temporary = TRUE,
                    overwrite = TRUE
  )
  
  cat_table_success(j, orig_name)
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
#'
#' @return success of adding, invisible
#' @export
add_cross_table <- function(table_name, 
                            con, 
                            db_dir){
  cat(crayon::bold("---", table_name, "---\n")) 
  
  dir <- file.path(db_dir, table_name)
  
  ffiles <- list.files(dir, "tsv$", full.names = TRUE)
  
  ft <- lapply(ffiles, read_dbtable)
  
  
  # remove table name from headers
  ft <- rename_table_headers(ft, table_name)
  
  # Turn all in to character, except first three key variables
  ft <- lapply(ft, dplyr::mutate_at, 
               .vars = dplyr::vars(-subject_id), 
               .funs = as.character)
  
  ffiles <- basename(ffiles)
  
  j <- list()
  for(i in 1:length(ft)){
    j[[i]] <- insert_table_cross(x = ft[[i]], 
                                 con = con, 
                                 table_name = table_name,
                                 orig_name = ffiles[i])
  }
  # get meta-data
  meta_info <- get_metadata(ft[[1]], table_name, dir)
  # add meta-data
  if (!is.null(meta_info)) {
    j <- insert_metadata(con, meta_info)
    cat_table_success(j, sprintf("%s metadata added", table_name))
  }
  cat("\n")
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
insert_table_long <- function(x, 
                              con, 
                              table_name, 
                              orig_name = table_name){
  
  j <- insert_table(x, con, table_name,
                    template = "sql/insert_long_table.sql",
                    #append = TRUE,
                    temporary = TRUE,
                    overwrite = TRUE
  )
  
  cat_table_success(j, orig_name)
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
                           db_dir){
  cat(crayon::bold("---", table_name, "---\n")) 
  
  dir <- file.path(db_dir, table_name)
  
  ffiles <- list.files(dir, "tsv$", full.names = TRUE)
  
  ft <- lapply(ffiles, read_dbtable)
  
  # remove table name from headers
  ft <- rename_table_headers(ft, table_name)
  
  
  
  # Turn all in to character, except first three key variables
  ft <- lapply(ft, dplyr::mutate_at, 
               .vars = dplyr::vars(-subject_id,
                                   -project_id,
                                   -wave_code), 
               .funs = as.character)
  
  ffiles <- basename(ffiles)
  
  j <- list()
  for(i in 1:length(ft)){
    j[[i]] <- insert_table_long(x = ft[[i]], 
                                con = con, 
                                table_name = table_name,
                                orig_name = ffiles[i])
  }
  
  # get meta-data
  meta_info <- get_metadata(ft[[1]], table_name, dir)
  # add meta-data
  if (!is.null(meta_info)) {
    j <- insert_metadata(con, meta_info)
    cat_table_success(j, sprintf("%s metadata added", table_name))
  }
  cat("\n")
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
insert_table_repeated <- function(x, 
                                  con, 
                                  table_name, 
                                  visit_id_column,
                                  orig_name = table_name){
  
  j <- insert_table(x, con, 
                    table_name,
                    visit_id_column,
                    template = "sql/insert_repeated_table.sql",
                    #append = TRUE,
                    temporary = TRUE,
                    overwrite = TRUE
  )
  
  cat_table_success(j, orig_name)
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
#' @param db_dir directory for the databse
#'
#' @return success of adding, invisible
#' @export
add_repeated_table <- function(table_name, 
                               con, 
                               db_dir){
  cat(crayon::bold("---", table_name, "---\n")) 
  
  dir <- file.path(db_dir, table_name)
  
  ffiles <- list.files(dir, "tsv$", full.names = TRUE)
  
  ft <- lapply(ffiles, read_dbtable)
  
  # take away table name from column headers
  ft <- lapply(ft, dplyr::rename_all, .funs = function(x) gsub(table_name, "", x))
  
  # forth column should be column making row unique
  # might want to change this later
  visit_id_column_old <- names(ft[[1]])[4]
  visit_id_column_new <- paste0("_", visit_id_column_old)
  cat(crayon::yellow("!"), "Forth column is ", crayon::italic(visit_id_column_old), "\n")
  ft <- lapply(ft, dplyr::rename_all, 
               .funs = function(x) gsub(visit_id_column_old, visit_id_column_new, x))
  
  # Turn all in to character, except first three key variables
  ft <- lapply(ft, dplyr::mutate_at, 
               .vars = dplyr::vars(-subject_id,
                                   -project_id,
                                   -wave_code), 
               .funs = as.character)
  
  ffiles <- basename(ffiles)
  
  j <- list()
  for(i in 1:length(ft)){
    j[[i]] <- insert_table_repeated(x = ft[[i]], 
                                    con = con, 
                                    table_name = table_name,
                                    visit_id_column = visit_id_column_new,
                                    orig_name = ffiles[i])
  }
  # get meta-data
  meta_info <- get_metadata(ft[[1]], table_name, dir)
  # add meta-data
  if (!is.null(meta_info)) {
    j <- insert_metadata(con, meta_info)
    cat_table_success(j, sprintf("%s metadata added", table_name))
  }
  invisible(j)
}


# read functions ----
#' Read database table
#' 
#' Convenience function to easily read 
#' db tables without needing to set
#' extra arguments
#'
#' @param path path to table
#'
#' @return data.frame
#' @export
read_dbtable <- function(path){
  read.table(path, header = TRUE, sep = "\t", 
             stringsAsFactors = FALSE)
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

