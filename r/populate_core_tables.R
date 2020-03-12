# Populate core tables
# Populate longitudinal tables

  # get helper functions
source('r/helpers.R')

# establish connection
con <- moasdb_connect()


args <- commandArgs(trailingOnly = TRUE)

stopifnot(length(args) == 1)

db_dir <- args[1]

add_core_tab <- function(tab, db_dir, con){
  filenm <- list.files(db_dir, paste0(tab,".tsv"), full.names = TRUE)
  dt <- read_dbtable(filenm)
  DBI::dbWriteTable(con, tab, dt, 
                    append = TRUE, row.name = FALSE)
}

# Add all core tables
lapply(c("projects", "subjects", "waves", "visits"),
       add_core_tab, con = con, db_dir = db_dir)


