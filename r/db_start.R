
# get helper functions
source('r/helpers.R')

# establish connection
con <- moasdb_connect()


j <- DBI::dbExecute(con, 
                    read_sql("sql/init_db.sql"))

