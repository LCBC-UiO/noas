source("dbimport/funcs-utils.R", echo = FALSE)
source("dbimport/funcs-printouts.R", echo = FALSE)
source("dbimport/funcs-populate.R", echo = FALSE)
source("dbimport/funcs-read.R", echo = FALSE)

#' Validate NOAS table
#' 
#' Function to validate tables in
#' a folder prior to adding to the NOAS
#' raw data folder for inclusion.
#'
#' @param path path to folder
#' @param type type of table, one of 'long', 'cross' or 'repeated'
#'
#' @export
validate_tables <- function(path, type){

  # Run first verifications, but not actual population of table
  suppressMessages(
    populate_table(path, con = NULL)
  )
  
  ffiles <- list.files(path, full.names = TRUE)
  ffiles <- ffiles[!grepl("json$", ffiles)]
  exts <- sapply(ffiles, check_table_ext) 

  delim <- check_delim(ffiles)
  
  keys <- check_keys(ffiles, type)
  
  cols <- check_cols(ffiles)

  if(all(delim, keys, cols, type_check)){
    message("Validation succeess: ", 
        "Tables can safely be added to the database.\n")
    invisible(TRUE)
  } else {
    stop("Validation failed: ", 
        "Tables cannot be added to the database.\n", call. = FALSE)
  }
    
}

#' Check if primary keys are set correctly
#' 
#' used by validate_tables, to check if
#' the files contain the correct primary keys
#'
#' @param files vector of file paths
#' @param type type of table 'cross', 'long', or 'repeated'
check_keys <- function(files, type){
  type <- match.arg(type, c("cross", "long", "repeated"))
  
  keys <- eval(parse(text=paste0("prim_keys()$", type)))
  
  tabs <- lapply(files, read_dbtable, nrows = 1)

  # check forth column is all the same for repeated
  if(type == "repeated"){
    nns <- sapply(tabs, function(x) names(x)[4])
    if(length(unique(nns)) != 1){
      cat(codes()$fail("Forth column is not the same across tables as required in repeated tables.\n"))
      return(FALSE)
    }
  }
  
  tabs <- lapply(tabs, function(x) x[,1:length(keys)])
  nams <- lapply(tabs, function(x) which(!keys %in% names(x)))
  idx <- unlist(lapply(nams, function(x) length(x) !=0 ))
  
  if(any(idx)){
    cat(codes()$fail("Some tables are missing necessary primary columns.\n"))
    
    k <- lapply(which(idx), 
                function(x) list(file = files[x],
                                 missing = prim_keys()$long[nams[[x]]]))
    j <- lapply(k, cat_miss_key) 
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
check_table_ext <- function(file){
  if(!grepl("tsv$", file)){
    warning(file, "does not have the '.tsv' extension. Files must be tab-separated.\n", call. = FALSE)
    return(FALSE)
  }else{
    return(TRUE)
  }
}

check_delim <- function(files){

  cont <- lapply(files, readLines, warn = FALSE)
  cont <- lapply(cont, function(x) x[1])
  
  strings <- c(",", "\t", ";")
  
  delim <- lapply(1:length(cont), function(x){
    k <- data.frame(lapply(strings, str_count, s = cont[[x]]),
                    stringsAsFactors = FALSE)
    names(k) <- strings
    k$file <- files[x]
    k
  })

  delim <- do.call(rbind, delim)
  delim$mm <- apply(delim[1:3], 1, max)
  
  df <- do.call(rbind, lapply(strings, function(x) {
    data.frame(file = delim$file, 
               mm = delim$mm,
               sep = x, 
               n = delim[, x],
               stringsAsFactors = FALSE)
  }))
  
  delim <- delim[delim$mm ==  delim$val,]
  delim <- delim[delim$key != "\t",]
  
  if( nrow(delim) < 1){
    return(TRUE) 
  }

  warning("Not all tables have tab (\\t) as separator\n", call. = FALSE)
  
  k <- lapply(split(delim, file), cat_delim_err)
  return(FALSE)
}


#' Check table columns
#' 
#' called by validate_table to check
#' if all files in a folder contain the 
#' same columns
#'
#' @param files vector of file paths
check_cols <- function(files){

  tabs <- lapply(files, read_dbtable)
  
  nams <- lapply(tabs, names)
  nams <- lapply(nams, function(x) gsub("^X", "", x) )
  
  n_nams <- unlist(lapply(nams, length))
  nn_nams <- length(unique(n_nams))
  
  if(nn_nams != 1){
    k_nams <- as.data.frame(table(n_nams), 
                            stringsAsFactors = FALSE)
    
    if(nrow(k_nams) == length(files)){
      warning("Files have different number of columns, they cannot be combined.\n", call. = FALSE)
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
    
    warning("Files contain different columns.\n", call. = FALSE)
    j <- lapply(diff_names, cat_err_cols)
    
    return(FALSE)  
  }
  
  nams <- do.call(rbind, nams)
  nams <- unique(nams)
  
  if(nrow(nams) == 1) return(TRUE)
  
  return("uncaught state")
}

