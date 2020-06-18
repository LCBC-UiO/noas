# table adding ----
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


# validation ----

cat_err_cols <- function(x, unicode = TRUE){
  
  miss <- if(length(x$missing) != 0){
    paste0("\nis", codes(unicode, with_char = FALSE)$note("missing "), "columns: ", 
           paste(sapply(x$missing, wrap_string), collapse = ", "))
  }else{
    ""
  }
  
  extra <- if(length(x$extra) != 0){
    paste0("\nhas", codes(unicode, with_char = FALSE)$note("extra "), "unknown columns: ", 
           paste(sapply(x$extra, wrap_string), collapse = ", "))
  }else{
    ""
  }
  
  cat("\n\nTable", codes(unicode)$bold(x$file), miss, extra)
}

cat_miss_key <- function(x,  unicode = TRUE){
  cat("\n\nTable", codes(unicode)$bold(x$file), 
      paste0("\nis", codes(unicode, with_char = FALSE)$note("missing "), "primary columns: ", 
             paste(sapply(x$missing, wrap_string), collapse = ", ")))
}

cat_delim_err <- function(x, unicode = TRUE){
  cat("\n\nTable", codes(unicode)$bold(x$file), 
      paste0("\nlooks like its separated with ", 
             codes(unicode, with_char = FALSE)$note(x$key))
  )
}