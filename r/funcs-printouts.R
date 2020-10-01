# table adding ----
#' Print out table adding success
#'
#' @param success logical vector for successes
#' @param names character vector of equal length as \code{success}
#' @param cat_type character. either ascii or unicode (no embelishment)
#'
#' @return
#' @export
#'
#' @examples
#' log_vect <- c(TRUE, TRUE, FALSE)
#' log_name <- c("tab1", "tab2", "tab3")
#' cat_table_success("tables added", log_vect, log_name)
cat_table_success <- function(success, names, cat_type = "ascii"){
  
  if(length(success) != length(names))
    stop("success and names are not of equal length", call. = FALSE)
  
  if(length(success) == 0){
    spec_cat(paste0(codes(cat_type)$note(), "no tables added"))
  }else{
    
    # if success is TRUE or 0 (adding to existing tables),
    # return green checkmark, else return red x
    j <- lapply(success, function(x) ifelse(x | x == 0, 
                                            codes(cat_type)$success(), 
                                            codes(cat_type)$fail()))
    j <- unlist(j)
    
    j <- paste(j, basename(names), sep=" ")
    
    spec_cat(j)
  }
  cat("\n")
}


cat_add_type <- function(type, cat_type = "ascii") {
  x <- paste0("'\n",
              codes(cat_type)$table(),
              codes(cat_type)$bold("Adding", type, "tables "), 
              codes(cat_type)$table(),
              "\n'")
  
  spec_cat(x)
}


# validation ----

cat_err_cols <- function(x, cat_type = "ascii"){
  
  miss <- if(length(x$missing) != 0){
    paste0("\nis", codes(cat_type, with_char = FALSE)$note("missing "), "columns: ", 
           paste(sapply(x$missing, wrap_string), collapse = ", "))
  }else{
    ""
  }
  
  extra <- if(length(x$extra) != 0){
    paste0("\nhas", codes(cat_type, with_char = FALSE)$note("extra "), "unknown columns: ", 
           paste(sapply(x$extra, wrap_string), collapse = ", "))
  }else{
    ""
  }
  
  x <- paste0("\n\nTable", codes(cat_type)$bold(x$file), miss, extra)
  
  spec_cat(x)
}

cat_miss_key <- function(x,  cat_type = "ascii"){
  xx <- paste0("\n\nTable", codes(cat_type)$bold(x$file), 
               paste0("\nis", codes(cat_type, with_char = FALSE)$note("missing "), "primary columns: ", 
                      paste(sapply(x$missing, wrap_string), collapse = ", ")))
  spec_cat(x)
}

cat_delim_err <- function(x, cat_type = "ascii"){
  x <- paste0("\n\nTable", codes(cat_type)$bold(x$file), 
              paste0("\nlooks like its separated with ", 
                     codes(cat_type, with_char = FALSE)$note(x$key))
  )
  spec_cat(x)
}


# special cat display ----
spec_cat <- function(x){
  system2("echo", x)
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
#' @param type character. either ascii or unicode (no embelishment)
#' @param with_char logical. if printout should include default prefixed characters,
#'
#' @return list of printouts functions
codes <- function(type = "ascii", with_char = TRUE){
  
  type = match.arg(type, c("ascii", "unicode"))
  
  chars <- switch(type,
                  "ascii" = list(
                    success = "\x1B[32m",
                    fail = "\x1B[31m",
                    note = "\x1B[33m",
                    table = "\x1B[35m",
                    bold = "\x1B[1m",
                    italic = "\x1B[4m"
                  ),
                  "unicode" = list(
                    success = "",
                    fail = "",
                    note = "",
                    table = "",
                    bold = "",
                    italic = ""
                  ))
  
  # add chars
  chars <- if(with_char & type == "ascii"){
    list(
      success = paste0(chars$success, "\U2713  "),
      fail = paste0(chars$fail, "\U10102  "),
      note = paste0(chars$note, "\U0021  "),
      table = paste0(chars$table, "\U25C6  "),
      bold = paste0(chars$bold, "\x1B[1m  "),
      italic = paste0(chars$italic, "\x1B[4m  ")
    )
  }else if(with_char){
    list(
      success = paste0(chars$success, "v  "),
      fail = paste0(chars$fail, "x  "),
      note = paste0(chars$note, "!  "),
      table = paste0(chars$table, "---  "),
      bold = chars$bold,
      italic = chars$italic
    )
  }
  
  
  # reset colours
  if(type == "ascii"){
    chars <- list(
      success = paste0(chars$success, "\x1B[39m"),
      fail = paste0(chars$fail, "\x1B[39m"),
      note = paste0(chars$note, "\x1B[39m"),
      table = paste0(chars$table, "\x1B[39m"),
      bold = chars$bold, 
      italic = chars$italic
    )
  }
  
  list(success = function(...) paste(chars$success, ...),
       fail = function(...) paste(chars$fail, ...),
       note = function(...) paste(chars$note, ...),
       table = function(...) paste(chars$table, ...),
       bold = function(...) paste(...),
       italic = function(...) paste(...)
  )
}
