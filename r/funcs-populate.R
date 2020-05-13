source("r/funcs-read.R", echo = FALSE)
source("r/funcs-utils.R", echo = FALSE)
source("r/funcs-table.R", echo = FALSE)

# populate functions ----
populate_core <- function(con, unicode = TRUE){
  db_dir <- file.path(read_config()$TABDIR, "core")
  
  cat_add_type("core", unicode = unicode)
  cat("\n")
  
  # Add all core tables
  j <- lapply(c("projects", "subjects", "waves", "visits"),
              add_core_tab, con = con, db_dir = db_dir, unicode = unicode)
}

populate_table <- function(type, con, unicode = TRUE) {
  
  db_dir <- file.path(read_config()$TABDIR, type)
 
  # list all directoried in the long db directory, except first, which is parent dir
  tables <- list.dirs(db_dir, full.names = FALSE)[-1]
  
  if(length(tables)>0){
    cat_add_type(type, unicode = unicode)
    
    func <- paste0("add_", type, "_table")
    
    # loop through all and add
    j <- sapply(tables, eval(parse(text=func)), 
                con = con, db_dir = db_dir, unicode = unicode) 
  }else{
    cat(codes(unicode)$note,codes(unicode)$bold("No", type, "tables to add\n"))
  }
}

