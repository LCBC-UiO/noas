source("dbimport/funcs-utils.R", echo = FALSE)
source("dbimport/funcs-printouts.R", echo = FALSE)
source("dbimport/funcs-read.R", echo = FALSE)

#' Validate NOAS table
#' 
#' Function to validate tables in
#' a folder prior to adding to the NOAS
#' raw data folder for inclusion.
#'
#' @param path path to folder
#' @param type type of table, one of 'long', 'cross' or 'repeated'
#' @param cat_type character. either ascii or unicode (no embelishment)
#'
#' @export
validate_tables <- function(path, type, cat_type = "ascii"){

  ffiles <- list.files(path, full.names = TRUE)
  ffiles <- ffiles[!grepl("json$", ffiles)]
  exts <- sapply(ffiles, check_table_ext, cat_type = cat_type) 

  delim <- check_delim(ffiles, cat_type)
  # Table type specific checks  
  type <- match.arg(type, c("cross", "long", "repeated"))
  
  keys <- check_keys(ffiles, type, cat_type = cat_type)
  
  cols <- check_cols(ffiles, cat_type = cat_type)
  cat("\n")
  if(all(delim, keys, cols)){
    cat(codes(cat_type)$success("Validation succeess: "), 
        "Tables can safely be added to the database.\n")
  }else{
    cat(codes(cat_type)$fail("Validation failed: "), 
        "Tables cannot be added to the database.\n")
  }
    
}

#' Check if primary keys are set correctly
#' 
#' used by validate_tables, to check if
#' the files contain the correct primary keys
#'
#' @param files vector of file paths
#' @param type type of table 'cross', 'long', or 'repeated'
#' @param cat_type character. either ascii or unicode (no embelishment)
check_keys <- function(files, type, cat_type = "ascii"){
  type <- match.arg(type, c("cross", "long", "repeated"))
  
  keys <- eval(parse(text=paste0("prim_keys()$", type)))
  
  tabs <- lapply(files, read_dbtable, nrows = 1)

  # check forth column is all the same for repeated
  if(type == "repeated"){
    nns <- sapply(tabs, function(x) names(x)[4])
    if(length(unique(nns)) != 1){
      cat(codes(cat_type)$fail("Forth column is not the same across tables as required in repeated tables.\n"))
      return(FALSE)
    }
  }
  
  tabs <- lapply(tabs, function(x) x[,1:length(keys)])
  nams <- lapply(tabs, function(x) which(!keys %in% names(x)))
  idx <- unlist(lapply(nams, function(x) length(x) !=0 ))
  
  if(any(idx)){
    cat(codes(cat_type)$fail("Some tables are missing necessary primary columns.\n"))
    
    k <- lapply(which(idx), 
                function(x) list(file = files[x],
                                 missing = prim_keys()$long[nams[[x]]]))
    j <- lapply(k, cat_miss_key, cat_type = cat_type) 
    return(FALSE)
  }else{
    return(TRUE)
  }
}

#' Check table extension
#' 
#' used by validate_tables to
#' check if data files have the correct 
#' table extension.
#'
#' @param file file path
#' @param cat_type character. either ascii or unicode (no embelishment)
check_table_ext <- function(file, cat_type = "ascii"){
  if(!grepl("tsv$", file)){
    cat(codes(cat_type)$fail(), 
        file, "does not have the '.tsv' extension. Files must be tab-separated.\n")
    return(FALSE)
  }else{
    return(TRUE)
  }
}

check_delim <- function(files, cat_type = "ascii"){

  cont <- lapply(files, readLines, warn = FALSE)
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
  delim <- delim[delim$mm ==  delim$mm,]
  delim <- delim[delim$key != "\t",]
  
  if( nrow(delim) < 1){
    return(TRUE) 
  }

  cat(codes(cat_type,)$fail("Not all tables have tab (\\t) as separator\n"))
  
  k <- lapply(split(delim, file), cat_delim_err, cat_type = cat_type)
  return(FALSE)
}


#' Check table columns
#' 
#' called by validate_table to check
#' if all files in a folder contain the 
#' same columns
#'
#' @param files vector of file paths
#' @param cat_type character. either ascii or unicode (no embelishment)
check_cols <- function(files, cat_type = "ascii"){
  
  tabs <- lapply(files, read_dbtable)
  
  nams <- lapply(tabs, names)
  nams <- lapply(nams, function(x) gsub("^X", "", x) )
  
  n_nams <- unlist(lapply(nams, length))
  nn_nams <- length(unique(n_nams))
  
  if(nn_nams != 1){
    k_nams <- as.data.frame(table(n_nams))
    
    if(nrow(k_nams) == length(files)){
      cat(codes(cat_type)$fail("Files have different number of columns, they cannot be combined.\n"))
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
    
    cat(codes(cat_type)$fail("Files contain different columns.\n"))
    j <- lapply(diff_names, cat_err_cols, cat_type = cat_type)
    
    return(FALSE)  
  }
  
  nams <- do.call(rbind, nams)
  nams <- unique(nams)
  
  if(nrow(nams) == 1) return(TRUE)
  
  return("uncaught state")
}

