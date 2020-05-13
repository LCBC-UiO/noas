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

codes <- function(unicode = TRUE){
  if(unicode){
    list(success = function(...) crayon::green("\U2713",...),
         fail = function(...) crayon::red("\U10102",...),
         note = function(...) crayon::yellow("\U0021",...),
         table = function(...) crayon::magenta("\U25C6",...),
         bold = function(...) crayon::bold(...),
         italic = function(...) crayon::italic(...)
    )
  }else{
    list(success = function(...) paste("v\t",...),
         fail = function(...) paste("x\t",...),
         note = function(...) paste("!\t",...),
         table = function(...) paste("---",...),
         bold = function(...) paste(...),
         italic = function(...) paste(...)
    )
  }
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
cat_table_success <- function(success, names, unicode = TRUE){
  
  if(length(success) != length(names))
    stop("success and names are not of equal length", call. = FALSE)
  
  if(length(success) == 0){
    cat(codes(unicode)$note(), "no tables added")
  }else{
    
    # if success is TRUE or 0 (adding to existing tables),
    # return green checkmark, else return red x
    j <- lapply(success, function(x) ifelse(x | x == 0, 
                                            codes(unicode)$success(), 
                                            codes(unicode)$fail()))
    j <- unlist(j)
    
    j <- paste(j, basename(names), sep=" ")
    cat(j)
  }
  cat("\n")
}


cat_add_type <- function(type, unicode = TRUE) {
  cat("\n",
      codes(unicode)$table(),
      codes(unicode)$bold("Adding", type, "tables "), 
      codes(unicode)$table(),
      "\n")
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




