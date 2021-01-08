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
    spec_cat(paste0(codes()$note(), "no tables added"))
  }else{
    
    # if success is TRUE or 0 (adding to existing tables),
    # return green checkmark, else return red x
    j <- lapply(success, function(x) ifelse(x | x == 0, 
                                            codes()$success(), 
                                            codes()$fail()))
    j <- unlist(j)
    
    pr <- strsplit(names, "\t")[[1]]
    pr[1] <- basename(pr[1])
    pr <- paste0(pr, collapse = "")
    
    j <- paste(j, pr, sep="")
    
    spec_cat(j)
  }
}

# validation ----

cat_err_cols <- function(x){
  
  miss <- if(length(x$missing) != 0){
    paste0("is", codes(with_char = FALSE)$note("missing "), "columns: ", 
           paste(sapply(x$missing, wrap_string), collapse = ", "))
  }else{
    ""
  }
  
  extra <- if(length(x$extra) != 0){
    paste0("has", codes(with_char = FALSE)$note("extra "), "unknown columns: ", 
           paste(sapply(x$extra, wrap_string), collapse = ", "))
  }else{
    ""
  }
  
  y <- c(paste("Table", codes()$bold(x$file)),
         miss, extra)
  cat("\n")
  j <- sapply(y, spec_cat)
}

cat_miss_key <- function(x){
  y <- c(paste0("Table", codes()$bold(x$file)), 
         paste0("is", codes(with_char = FALSE)$note("missing "), "primary columns: ", 
                paste(sapply(x$missing, wrap_string), collapse = ", ")))
  cat("\n")
  j <- sapply(y, spec_cat)
}

cat_delim_err <- function(x){
  x <- c(paste0("Table", codes()$fail(x$file)), 
         codes(with_char = FALSE)$note(x$key)
  )
  cat("\n")
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
      success = paste0(chars$success, "v\t"),
      fail = paste0(chars$fail, "x\t"),
      note = paste0(chars$note, "!\t"),
      table = paste0(chars$table, "---\t"))
  }
  
  list(success = function(...) paste(chars$success, ...),
       fail = function(...) paste(chars$fail, ...),
       note = function(...) paste(chars$note, ...),
       table = function(...) paste(chars$table, ...)
  )
}
