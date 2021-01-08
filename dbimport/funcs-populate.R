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
  
  tabs <- data.frame(
    tabel = list.files(db_dir, "_noas.json", recursive = TRUE, full.names = TRUE)
  )
  
  types <- lapply(tabs$tabel, jsonlite::read_json)
  tabs$type <- unlist(types)
  tabs$type <- sapply(tabs$type, function(x) switch(x, 
                                       "longitudinal" = "long",
                                       "cross-sectional" = "cross",
                                       "repeated" = "repeated")
  )
  tabs$tabel <- dirname(tabs$tabel)

  mapply(populate_table,
         table = gsub(db_dir, "", tabs$tabel),
         type = tabs$type,
         MoreArgs = list(con = con)
         )
}

populate_table <- function(table, type, con) {

  if(length(table)>0){

    func <- paste0("add_", type, "_table")
    
    # loop through all and add
    j <- sapply(table, eval(parse(text=func)), 
                con = con, db_dir = read_config()$TABDIR) 
  }else{
    cat(codes()$note(), paste0("No ", table, " to add\n"))
  }
}

