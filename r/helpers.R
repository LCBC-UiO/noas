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
    
    j <- lapply(success, function(x) ifelse(x, 
                                            crayon::green("\U2713"), 
                                            crayon::red("\U10102")))
    j <- unlist(j)
    
    j <- paste(j, names, sep=" ")
    cat(j)
  }
  cat("\n")
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
  
  cat(j)
  cat_table_success(j, orig_name)
  invisible(j)
}

#' Add long data to a table
#' 
#' calls \code{\link{insert_table_long}}
#' to add more data to the data-base
#' Where do we use this??
#' 
#' @param x data.frame containing data to add
#' @param cols selection of columns to add
#' @param predicate any logic to apply to reduce rows of data
#' @param table_name name to give the table
#'
#' @export
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
  
  # take away table name from column headers
  ft <- lapply(ft, dplyr::rename_all, .funs = function(x) gsub(table_name, "", x))
  
  # Turn all in to character
  ft <- lapply(ft, dplyr::mutate_at, 
               .vars = dplyr::vars(dplyr::starts_with("_")), 
               .funs = as.character)
  
  ffiles <- basename(ffiles)
  
  j <- list()
  for(i in 1:length(ft)){
    j[[i]] <- insert_table_long(x = ft[[i]], 
                                con = con, 
                                table_name = table_name,
                                orig_name = ffiles[i])
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
    for (line in readLines(fn)) {
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

