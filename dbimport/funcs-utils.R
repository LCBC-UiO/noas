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


#' List primary keys of the table types
#' 
#' Different table types have differnt primary keys.
#' This functions returns a list containing the 
#' primary keys for each table type
#'
#' @return list of primary keys by table type
prim_keys <- function(){
  list(
    cross = "subject_id",
    long = c("subject_id", "project_id", "wave_code"),
    repeated = c("subject_id", "project_id", "wave_code")
  )
}


#' Rename headers
#'
#' checks and renames a table header
#' if it has the exact same name as the 
#' table it self. 
#' 
#' @param ft data
#' @param table_name tale name
rename_table_headers <- function(ft, key_vars){
  lapply(ft, .renm_cols, cols = key_vars)
}

.renm_cols <- function(data, cols){
  
  idx <- !(names(data) %in% cols)
  
  names(data)[idx] <- fix_names(names(data)[idx])
  data
}

#' Cleanup column names
#' 
#' function to do initial cleaning
#' of columns names so that they are
#' lower case and do not start with 
#' unwanted characters
#'
#' @param x string. column name
#'
#' @return string of cleaned column name
fix_names <- function(x){
  x <- gsub("^X", "", x)
  x <- tolower(x)
  paste0("_", x)
}

get_rows <- function(con, table){
  if(DBI::dbExistsTable(con, table)){
    query <- sprintf("select * from %s;", table)
    res <- DBI::dbSendQuery(con, query)
    x <- DBI::dbFetch(res)
    DBI::dbClearResult(res)
    return(nrow(x))
  }else{
    return(0)
  }
}

type_2_rclass <- function(type){
  lapply(type, type_change)
}

sql_templates <- function(type){
  type <- match.arg(type, c("core", "cross", "repeated", "long"))
  
  switch(type,
         "cross" = "dbimport/sql/insert_cross_table.sql",
         "long" = "dbimport/sql/insert_long_table.sql",
         "repeated" = "dbimport/sql/insert_repeated_table.sql")
}

type_change <- function(x){
  j <- switch(x,
              "float" = as.numeric,
              "int" = as.integer,
              "date" = as.Date,
              #"boolean" = as_logical,
              #"hms" = "time",
              #  "duration",
              "datetime" = as.POSIXct.Date
  )
  
  if(is.null(j)) j <- as.character
  j
}

change_col_type <- function(data, column, func){
  for(i in 1:length(column)){
    data[, column[i]] <- func[[i]](data[, column[i]])
  }
  as.data.frame(
    data, 
    stringsAsFactor = FALSE
  )
}

# find if _noas.json is there
# Read it in 
read_noas_json <- function(dir_path){
  noas <- file.path(dir_path, "_noas.json")
  
  if(!file.exists(noas))
    stop("Table '", basename(dir_path), "' does not have a '_noas.json' file, and cannot be added",
         call. = FALSE)
  
  # find type of data from json
  jsonlite::read_json(noas, simplifyVector = TRUE) 
}

noas_table_type <- function(dir_path){
  type <- read_noas_json(dir_path)
  table_type(type$table_type)
}

table_type <- function(x){
  switch(x, 
         "longitudinal" = "long",
         "cross-sectional" = "cross",
         "repeated" = "repeated",
         NA_character_) 
}


#' Count characters in string
#' 
#' function to count the number of 
#' a given character in a string.
#'
#' @param char character to count
#' @param s string to count in
#'
#' @return integer
str_count <- function(char, s) {
  s2 <- gsub(char,"",s)
  return (nchar(s) - nchar(s2))
}


# convenience function to assign "default" value if 
# input value is NA
`%||%` <- function(a, b){
  if( !any(c(is.null(a), is.na(a)))) a else b
}