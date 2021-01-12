# table adding ----
#' Print out table adding success
#'
#' @param success logical vector for successes
#' @param names character vector of equal length as \code{success}
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
    spec_cat(sprintf("%2s No tables addes", codes()$note()))
  }else{
    
    # if success is TRUE or 0 (adding to existing tables),
    # return green checkmark, else return red x
    j <- lapply(success, function(x) ifelse(x | x == 0, 
                                            codes()$success(), 
                                            codes()$fail()))
    j <- unlist(j) 
    
    pr <- strsplit(names, "\t")[[1]]
    if(length(pr) == 3){ 
      pr[2] <- basename(pr[2])
      pr <- c(pr[1], "", basename(pr[2]), pr[3])
    }
    
    pr <- sprintf("%s %8s %20s %20s %30s", j, pr[1] , 
                  pr[2] %||% "", pr[3] %||% "", pr[4] %||% "")    
    
    spec_cat(pr)
  }
}

# validation ----

cat_err_cols <- function(x){
  
  miss <- if(length(x$missing) != 0){
    sprintf("is missing columns:\n, %s",  
           paste(sapply(x$missing, wrap_string), collapse = ", "))
  }else{
    ""
  }
  
  extra <- if(length(x$extra) != 0){
    sprintf("has extra unknown columns:\n%s", 
           paste(sapply(x$extra, wrap_string), collapse = ", "))
  }else{
    ""
  }
  
  y <- sprintf("\nTable %s\n%s\n%s", x$file, miss, extra)
  j <- sapply(y, spec_cat)
}

cat_miss_key <- function(x){
  y <- sprintf("\nMissing primary columns:\t%s", 
              paste(sapply(x$missing, wrap_string), collapse = ", "))
  warning(y, call. = FALSE)
}

cat_delim_err <- function(x){
  y <- sprintf("\n%s Table %s", codes()$fail, x$file, x$key)
  j <- sapply(y, spec_cat)
}


# special cat display ----
spec_cat <- function(x){
  cat(x, sep="\n")
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
#' @param type character. either ascii or unicode (no embelishment)
#' @param with_char logical. if printout should include default prefixed characters,
#'
#' @return list of printouts functions
codes <- function(with_char = TRUE){
  
  chars <- list(
    success = "",
    fail = "",
    note = "",
    table = ""
  )
  # add chars
  chars <- if(with_char){
    list(
      success = sprintf("%s%s  ", chars$success, "v"),
      fail    = sprintf("%s%s  ", chars$fail,    "x"),
      note    = sprintf("%s%s  ", chars$note,    "!"),
      table   = sprintf("%s%s  ", chars$table,    "---"))
  }
  
  list(success = function(...) paste(chars$success, ...),
       fail = function(...) paste(chars$fail, ...),
       note = function(...) paste(chars$note, ...),
       table = function(...) paste(chars$table, ...)
  )
}


