# Populate core tables
# Populate longitudinal tables

  # get helper functions
source('r/helpers.R')

# establish connection
con <- moasdb_connect()

db_dir <- read_config()$TABDIR_CORE

cat(crayon::bold("\nAdding core tables\n"))

add_core_tab <- function(tab, db_dir, con){
  filenm <- list.files(db_dir, paste0(tab,".tsv"), full.names = TRUE)
  dt <- read_dbtable(filenm)
  j <- DBI::dbWriteTable(con, tab, dt, 
                    append = TRUE, row.name = FALSE)
  
  cat_table_success(j, tab)
  invisible(j)
}

# Add all core tables
j <- lapply(c("projects", "subjects", "waves", "visits"),
       add_core_tab, con = con, db_dir = db_dir)


