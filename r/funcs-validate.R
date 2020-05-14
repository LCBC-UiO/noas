source("r/funcs-utils.R", echo = FALSE)
source("r/funcs-read.R", echo = FALSE)

#' Validate NOAS table
#' 
#' Function to validate tables in
#' a folder prior to adding to the NOAS
#' raw data folder for inclusion.
#'
#' @param path path to folder
#' @param type type of table, one of 'long', 'cross' or 'repeated'
#' @param unicode logical. if unicode printout should be toggled
#'
#' @export
validate_tables <- function(path, type, unicode = TRUE){
  
  ffiles <- list.files(path, full.names = TRUE)
  ffiles <- ffiles[!grepl("json$", ffiles)]
  exts <- sapply(ffiles, check_table_ext, unicode = unicode) 
  
  delim <- check_delim(ffiles, unicode)
  # Table type specific checks  
  type <- match.arg(type, c("cross", "long", "repeated"))
  
  keys <- check_keys(ffiles, type, unicode = unicode)
  
  cols <- check_cols(ffiles, unicode = unicode)
  
}



#' Check if primary keys are set correctly
#' 
#' used by validate_tables, to check if
#' the files contain the correct primary keys
#'
#' @param files vector of file paths
#' @param type type of table 'cross', 'long', or 'repeated'
#' @param unicode logical. if unicode printout should be toggled
check_keys <- function(files, type, unicode = TRUE){
  # browser()
  keys <- eval(parse(text=paste0("prim_keys()$", type)))
  
  tabs <- lapply(files, read_dbtable, nrows = 1)
  tabs <- lapply(tabs, function(x) x[,1:3])
  nams <- lapply(tabs, function(x) which(!keys %in% names(x)))
  idx <- unlist(lapply(nams, function(x) length(x) !=0 ))
  
  if(any(idx)){
    cat(codes(unicode, with_char = FALSE)$fail("\nValidation failed: "), 
        "Some tables are missing necessary primary columns.")
    
    k <- lapply(which(idx), 
                function(x) list(file = files[x],
                                 missing = prim_keys()$long[nams[[x]]]))
    j <- lapply(k, cat_miss_key, unicode = unicode) 
  }
}

#' Check table extension
#' 
#' used by validate_tables to
#' check if data files have the correct 
#' table extension.
#'
#' @param file file path
#' @param unicode logical. if unicode printout should be toggled
check_table_ext <- function(file, unicode = TRUE){
  if(!grepl("tsv$", file)){
    cat(codes(unicode, with_char = FALSE)$fail("\nValidation fail: "), 
        file, "does not have the '.tsv' extension. Files must be tab-separated.")
    return(FALSE)
  }else{
    return(TRUE)
  }
}

check_delim <- function(files, unicode = TRUE){
  cont <- lapply(files, readLines)
  cont <- lapply(cont, function(x) x[1])
  
  strings <- c(",", "\t", ";")
  
  delim <- lapply(cont, function(x){
    k <- data.frame(lapply(strings, str_count, s = x))
    names(k) = strings
    k
  })
  names(delim) <- files
  delim <- dplyr::bind_rows(delim, .id = "file")
  delim <- dplyr::mutate(delim, mm = max(c(`,`, `\t`, `;`)))
  
  delim <- tidyr::gather(delim, key, val, -file, -mm)
  delim <- dplyr::filter(delim, mm == val)
  
  delim <- dplyr::filter(delim, key != "\t")
  
  if( nrow(delim) < 1){
    return(TRUE) 
  }

  cat(codes(unicode, with_char = FALSE)$fail("\nValidation failed: "), 
      "Not all tables have tab (\t) as separator")
  
  k <- lapply(split(delim, file), cat_delim_err, unicode = TRUE)
}


#' Check table columns
#' 
#' called by validate_table to check
#' if all files in a folder contain the 
#' same columns
#'
#' @param files vector of file paths
#' @param unicode logical. if unicode printout should be toggled
check_cols <- function(files, unicode = TRUE){
  
  tabs <- lapply(files, read_dbtable)
  
  nams <- lapply(tabs, names)
  nams <- lapply(nams, function(x) gsub("^X", "", x) )
  
  n_nams <- unlist(lapply(nams, length))
  nn_nams <- length(unique(n_nams))
  
  if(nn_nams != 1){
    k_nams <- dplyr::as_tibble(table(n_nams))
    
    if(nrow(k_nams) == length(files)){
      cat(codes(unicode, with_char = FALSE)$fail("\n\nValidation failed: "), 
          "all files have different number of columns, they cannot be combined.")
      return(FALSE)
    }
    
    common <- k_nams$n_nams[k_nams$n == max(k_nams$n)]
    common_nams <- nams[[grep(common, n_nams)[[1]]]]
    
    errs <- grep(common, n_nams, invert = TRUE)
    
    err_files <- files[]
    
    diff_names <- lapply(errs, function(x) 
      list( extra = nams[[x]][!nams[[x]] %in% common_nams],
            missing = common_nams[!common_nams %in%nams[[x]]],
            file = files[x])
    )
    
    cat(codes(unicode, with_char = FALSE)$fail("\n\nValidation failed: "), "Files contain different columns.")
    j <- lapply(diff_names, cat_err_cols, unicode = unicode)
    
    return(FALSE)  
  }
  
  nams <- do.call(rbind, nams)
  nams <- unique(nams)
  
  if(nrow(nams) == 1) return(TRUE)
  
  return("uncaught state")
}


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

str_count <- function(char, s) {
  s2 <- gsub(char,"",s)
  return (nchar(s) - nchar(s2))
}
