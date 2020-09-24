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

#' Printout codes
#' 
#' When printing out diagnostics to the
#' terminal, the charachter settings for
#' this may depend on the terminal and 
#' interacitivity of running the functions.
#' This function returns a list for printing
#' certain pre-set printout versions. These
#' vary depending on the contect to the printout, and
#' the type of printout.
#' 
#'
#' @param unicode logical. should the printout include unicode characters
#' @param with_char logical. if printout should include default prefixed characters,
#'
#' @return list of printouts functions
codes <- function(unicode = TRUE, with_char = TRUE){
  
  chars <- list(
      success = "\x1B[32m",
      fail = "\x1B[31m",
      note = "\x1B[33m",
      table = "\x1B[35m",
      bold = "\x1B[1m",
      italic = "\x1B[4m"
      )
  
  # add chars
  if(with_char)
    chars <- list(
      success = paste0(chars$success, "v  "),
      fail = paste0(chars$fail, "x  "),
      note = paste0(chars$note, "!  "),
      table = paste0(chars$table, "---  "),
      bold = "\x1B[1m  ",
      italic = "\x1B[4m  "
    )
  
  # reset colours
  chars <- list(
    success = paste0(chars$success, "\x1B[39m"),
    fail = paste0(chars$fail, "\x1B[39m"),
    note = paste0(chars$note, "\x1B[39m"),
    table = paste0(chars$table, "\x1B[39m"),
    bold = chars$bold, 
    italic = chars$italic
  )

    list(success = function(...) paste(chars$success, ...),
         fail = function(...) paste(chars$fail, ...),
         note = function(...) paste(chars$note, ...),
         table = function(...) paste(chars$table, ...),
         bold = function(...) paste(...),
         italic = function(...) paste(...)
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

type_2_rclass <- function(type){
  lapply(type, type_change)
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
  dplyr::as_tibble(
    data
  )
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



