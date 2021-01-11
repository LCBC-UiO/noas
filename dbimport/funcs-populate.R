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
 
  # Loop through and populate
  k <- sapply(tabs, populate_table, con = con)
}

populate_table <- function(table, con = NULL) {
  
  table_path <- normalizePath(table)
  table <- basename(table)

  type <- read_noas_json(table_path)
  type <- table_type(type$table_type)
  
  if(is.na(type))
    stop("Table '", table, "' does not have a correctly specified 'table_type' in the' _noas.json'",
         call. = FALSE)
  
  if(is.null(con)){
    message("Database connection not supplied, table not populated.")
    return()
  }
  
  if(length(table) > 0){

    func <- sprintf("add_%s_table", type)
    
    # loop through all table .tsv and add
    j <- sapply(table, eval(parse(text=func)), 
                con = con, db_dir = read_config()$TABDIR) 
  }else{
    cat(codes()$note(), paste0("No ", table, " to add\n"))
  }
}

