source("dbimport/funcs-utils.R", echo = FALSE)
source("dbimport/funcs-printouts.R", echo = FALSE)

#' Validate NOAS table
#' 
#' Function to validate tables in
#' a folder prior to adding to the NOAS
#' raw data folder for inclusion.
#'
#' @param path path to folder
#'
#' @export
validate_table <- function(path, noas_jsn = NULL, verbose = getOption("valid_success")){

  # if called from command line, noas_jsn is not there
  if(is.null(noas_jsn)) noas_json <- read_noas_json(path)
  
  tryCatch(
    {
      db_table_type <- noas_dbtable_type(noas_jsn$table_type)
      type_check <- TRUE
    }, error = function(e) {
      type_check <- FALSE
      warning(e$message, call. = FALSE)
    }
  )
  
  ffiles <- list.files(path, full.names = TRUE)
  ffiles <- ffiles[!grepl("json$", ffiles)]
  
  exts <- all(sapply(ffiles, check_table_ext))
  deli <- check_delim(ffiles)
  keys <- check_keys(ffiles, db_table_type)
  cols <- check_cols(ffiles)

  if(all(c(deli, keys, cols, exts, type_check))){
    
    if(is.null(verbose)){
      verbose <- TRUE
    }
    
    if(verbose)
      cat("\nValidation succeess: ", 
          "Tables can safely be added to the database.\n")
  } else {
    stop("Validation failed: ", 
        "Tables cannot be added to the database.\n", 
        call. = FALSE)
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
  keys <- prim_keys()[[type]]
  
  tabs <- lapply(files, read_dbtable, nrows = 1)

  # check forth column is all the same for repeated
  if(type == "repeated"){
    nns <- sapply(tabs, function(x) names(x)[4])
    if(length(unique(nns)) != 1){
      stop("Forth column is not the same across tables as required in repeated tables.\n",
           call. = FALSE)
    }
  }
  
  nams <- lapply(tabs, function(x) !(keys %in% names(x)))

  if(any(unlist(nams))){
    k <- which(sapply(nams, function(x) any(x)))
    k <- lapply(k, 
                function(x) list(file = files[x],
                                 missing = keys[nams[[x]]])
    )
    
    stop("Some tables are missing necessary primary columns.\n",
         sapply(k, cat_miss_key),
         call. = FALSE)
  }
  
  TRUE
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
    stop(file, "does not have the '.tsv' extension. Files must be tab-separated.\n",
         call. = FALSE)
  }
  TRUE
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

  stop("Not all tables have tab (\\t) as separator\n",
       lapply(split(delim, file), cat_delim_err),
       call. = FALSE)
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
      stop("Files have different number of columns, they cannot be combined.\n",
           call. = FALSE)
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
    
    stop("Files contain different columns.\n",
         lapply(diff_names, cat_err_cols),
         call. = FALSE)
  }
  
  nams <- do.call(rbind, nams)
  nams <- unique(nams)
  
  if(nrow(nams) != 1){
    stop("File columns in differing order. Make sure all files present the columns in the same sequence.\n",
            call. = FALSE)
  } 
  TRUE
}

