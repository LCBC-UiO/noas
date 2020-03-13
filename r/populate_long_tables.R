# Populate longitudinal tables
library(dplyr)

# get helper functions
source('r/helpers.R')

# establish connection
con <- moasdb_connect()

db_dir <- read_config()$TABDIR_LONG

add_long_table <- function(table_name, con, 
                           db_dir){

  dir <- file.path(db_dir, table_name)
  
  ffiles <- list.files(dir, "tsv$", full.names = TRUE)

  ft <- lapply(ffiles, read_dbtable)
  
  # take away table name from column headers
  ft <- lapply(ft, dplyr::rename_all, .funs = function(x) gsub(table_name, "", x))
  
  # Turn all in to character
  ft <- lapply(ft, dplyr::mutate_at, 
               .vars = dplyr::vars(dplyr::starts_with("_")), 
               .funs = as.character)
  
  lapply(ft, insert_table_long, con = con, table_name = table_name)
}


# list all directoried in the long db directory, except first, which is parent dir
long_tables <- list.dirs(db_dir, full.names = FALSE)[-1]

# loop through all and add
sapply(long_tables, add_long_table, con = con, db_dir = db_dir)


