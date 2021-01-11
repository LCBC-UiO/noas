source("dbimport/funcs-read.R", echo = FALSE)
source("dbimport/funcs-utils.R", echo = FALSE)
source("dbimport/funcs-table.R", echo = FALSE)

# populate functions ----
populate_core <- function(con){
  db_dir <- file.path(read_config()$TABDIR, "core")
  
  # Add all core tables
  j <- lapply(c("subjects", "projects", "waves", "visits"),
              add_core_tab, con = con, db_dir = db_dir)
}

populate_tables <- function(con){
  db_dir <- read_config()$TABDIR

  # Find top-level folders
  tabs <- list.dirs(db_dir, recursive = FALSE, full.names = TRUE)
  tabs <- tabs[!grepl("core", tabs)]
  
  # find if _noas.json is there
  noas <- sapply(tabs, list.files, pattern="_noas.json", full.names = TRUE)

  # find type of data from json
  types <- lapply(noas, function(x){
    if(length(x)>0){ 
      j <- jsonlite::read_json(normalizePath(x[[1]])) 
      j[[1]]$table_type
    } else {
      NA_character_
    }
  })
  types <- unname(unlist(types))
  
  tabs <- data.frame(
    tabel = basename(tabs),
    noas = sapply(noas, function(x) ifelse(length(x) > 0, TRUE, FALSE), simplify = TRUE),
    type = unname(unlist(types))
  )

  k <- mapply(populate_table,
         table = tabs$tabel,
         type = tabs$type,
         noas = tabs$noas,
         MoreArgs = list(con = con)
         )
}

populate_table <- function(table, type, noas, con) {
  
  if(!noas)
    stop("Table '", table, "' does not have a '_noas.json' file, and cannot be added",
         call. = FALSE)
  
  type <- switch(type, 
                 "longitudinal" = "long",
                 "cross-sectional" = "cross",
                 "repeated" = "repeated",
                 NA_character_) 
  
  if(is.na(type))
    stop("Table '", table, "' does not have a correctly specified 'table_type' in the' _noas.json'",
         call. = FALSE)
  
  
  if(length(table) > 0){

    func <- sprintf("add_%s_table", type)
    
    # loop through all and add
    j <- sapply(table, eval(parse(text=func)), 
                con = con, db_dir = read_config()$TABDIR) 
  }else{
    cat(codes()$note(), paste0("No ", table, " to add\n"))
  }
}

