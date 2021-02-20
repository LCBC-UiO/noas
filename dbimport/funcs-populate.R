source("dbimport/funcs-validate.R", echo = FALSE)
source("dbimport/funcs-table.R", echo = FALSE)

# populate functions ----
populate_core <- function(con){
  if(is.null(con)){
    stop("Database connection not supplied, table not populated.")
  }
  
  # Add all core tables
  j <- lapply(c("subjects", "projects", "waves", "visits"),
              add_core_tab, con = con)
}

populate_tables <- function(con){
  if(is.null(con)){
    stop("Database connection not supplied, table not populated.")
  }
  
  db_dir <- file.path(read_config()$TABDIR,
                      "non_core")
  
  # Find top-level folders
  tabs <- list.dirs(db_dir, recursive = FALSE, full.names = TRUE)
  tabs <- normalizePath(tabs)
  tabs <- sapply(tabs, file.mtime)
  tabs <- tabs[rev(order(tabs))]
  
  # Loop through and populate
  k <- sapply(names(tabs), populate_table, con = con)
}

populate_table <- function(table, con = NULL) {
  suppressMessages(
    validate_table(table)
  )
  cat(basename(table), "\n")

  type <- noas_dbtable_type(
    read_noas_json(table)$table_type
  )

  if(length(table) > 0){
    
    func <- switch(
      type, 
      "long" = add_long_table,
      "cross" = add_cross_table,
      "repeated" = add_repeated_table
    )
    
    # loop through all table .tsv and add
    j <- sapply(table, func, con = con) 
  }else{
    stop("There are no tables in", basename(table))
  }
}


