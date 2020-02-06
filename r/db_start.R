
# get helper functions
source('r/helpers.R')

# establish connection
con <- moasdb_connect()


k <- read_sql("sql/init_db.sql")


j <- DBI::dbExecute(con, k)

