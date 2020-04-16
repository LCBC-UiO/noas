# Populate longitudinal tables
library(dplyr, quietly = TRUE, warn.conflicts = FALSE)

# get helper functions
source('r/helpers.R')

# establish connection
con <- moasdb_connect()

db_dir <- read_config()$TABDIR_LONG

# list all directoried in the long db directory, except first, which is parent dir
long_tables <- list.dirs(db_dir, full.names = FALSE)[-1]

cat(crayon::bold("\nAdding long tables\n"))

# loop through all and add
j <- sapply(long_tables, add_long_table, con = con, db_dir = db_dir)


