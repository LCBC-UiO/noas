# Populate longitudinal tables

# get helper functions
source('r/helpers.R')

# establish connection
con <- moasdb_connect()

db_dir <- read_config()$TABDIR_REPEATED

# list all directoried in the long db directory, except first, which is parent dir
tables <- list.dirs(db_dir, full.names = FALSE)[-1]

cat(crayon::bold("\nAdding repeated tables\n"))

# loop through all and add
j <- sapply(tables, add_repeated_table, con = con, db_dir = db_dir)


