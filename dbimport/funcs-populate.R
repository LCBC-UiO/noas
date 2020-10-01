source("dbimport/funcs-read.R", echo = FALSE)
source("dbimport/funcs-utils.R", echo = FALSE)
source("dbimport/funcs-table.R", echo = FALSE)

# populate functions ----
#' @param cat_type character. either ascii or unicode (no embelishment)
populate_core <- function(con, cat_type = "ascii"){
  db_dir <- file.path(read_config()$TABDIR, "core")
  
  cat_add_type("core", cat_type = cat_type)
  cat("\n")
  
  # Add all core tables
  j <- lapply(c("projects", "subjects", "waves", "visits"),
              add_core_tab, con = con, db_dir = db_dir, cat_type = cat_type)
}

#' @param cat_type character. either ascii or unicode (no embellishment)
populate_table <- function(type, con, cat_type = "ascii") {
  
  db_dir <- file.path(read_config()$TABDIR, type)
 
  # list all directories in the long db directory
  # list only dirs with tsv files, and 
  # list only final full directory with tables in
  tables <- list.files(db_dir, pattern = ".tsv", recursive = TRUE)
  tables <- unique(dirname(tables))

  if(length(tables)>0){
    cat_add_type(type, cat_type = cat_type)
    
    func <- paste0("add_", type, "_table")
    
    # loop through all and add
    j <- sapply(tables, eval(parse(text=func)), 
                con = con, db_dir = db_dir, cat_type = cat_type) 
  }else{
    cat(codes(cat_type)$note,codes(cat_type)$bold("No", type, "tables to add\n"))
  }
}

