# Populate core tables
# Populate longitudinal tables

  # get helper functions
source('r/helpers.R')

# establish connection
con <- moasdb_connect()

db_dir <- "/tsd/p23/data/durable/tmp/db_clean_data_tmp/core/"

add_core_tab <- function(tab, con){
  filenm <- list.files(db_dir, paste0(tab,".tsv"), full.names = TRUE)
  dt <- read_dbtable(filenm)
  DBI::dbWriteTable(con, tab, dt, 
                    append = TRUE, row.name = FALSE)
}

# Add all core tables
lapply(c("projects", "subjects", "waves", "visits"),
       add_core_tab, con = con)


