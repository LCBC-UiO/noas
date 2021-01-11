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

populate_table <- function(type, con) {
  
  db_dir <- file.path(read_config()$TABDIR, type)
 
  # list all directories in the long db directory
  # list only dirs with tsv files, and 
  # list only final full directory with tables in
  tables <- list.files(db_dir, pattern = ".tsv", recursive = TRUE)
  tables <- unique(dirname(tables))

  if(length(tables)>0){

    func <- paste0("add_", type, "_table")
    
    # loop through all and add
    j <- sapply(tables, eval(parse(text=func)), 
                con = con, db_dir = db_dir) 
  }else{
    cat(codes()$note(), paste0("No ", type, " tables to add\n"))
  }
}

