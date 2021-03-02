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
  # override with any existing NOAS_XXX env variables
  for (key in names(cfg)) {
    nkey <- sprintf("NOAS_%s", key)
    v <- Sys.getenv(nkey)
    # only works for non-empty env vars
    if (v != "") {
      cfg[key] = v
    }
  }
  return(cfg)
}


#' List primary keys of the table types
#' 
#' Different table types have different primary keys.
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

sql_templates <- function(type){
  switch(type,
         cross = "dbimport/sql/insert_cross_table.sql",
         long = "dbimport/sql/insert_long_table.sql",
         repeated = "dbimport/sql/insert_repeated_table.sql"
  )
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

#' Rename headers
#'
#' checks and renames a table header
#' if it has the exact same name as the 
#' table it self. 
#' 
#' @param ft data
#' @param table_name tale name
rename_table_headers <- function(ft, key_vars){
  fix_names <- function(x){
    x <- gsub("^X", "", x)
    x <- tolower(x)
    paste0("_", x)
  }
  
  .renm_cols <- function(data, cols){
    idx <- !(names(data) %in% cols)
    names(data)[idx] <- fix_names(names(data)[idx])
    data
  }
  
  lapply(ft, .renm_cols, cols = key_vars)
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
  nchar(s) - nchar(s2)
}


# convenience function to assign "default" value if 
# input value is NA
`%||%` <- function(a, b){
  if( !any(c(is.null(a), is.na(a)))) a else b
}

# noas json ----

# find if _noas.json is there
# Read it in and check fields
read_noas_json <- function(dir_path){
  noas <- file.path(dir_path, "_noas.json")
  # check if we have the file
  if(!file.exists(noas))
    stop("Table '", basename(dir_path), "' does not have a '_noas.json' file, and cannot be added")
  # read json
  jsn <- jsonlite::read_json(noas, simplifyVector = TRUE) 
  # check if we have table_type
  if (! jsn$table_type %in% names(k_noas_table_types())) {
    stop(sprintf("Unrecognised table type \"%s\" in file \"%s\"", jsn$table_type, dir_path))
  }
  jsn
}

k_noas_table_types <- function(){
  c(
    "longitudinal" = "long",
    "cross-sectional" = "cross",
    "repeated" = "repeated"
  )
}

# translate JOSN table_type to short db table_type
noas_dbtable_type <- function(jsntable_type){
  type <- k_noas_table_types()[jsntable_type]
  stopifnot(!is.na(type))
  type
}
