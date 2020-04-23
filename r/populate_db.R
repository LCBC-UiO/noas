
# get helper functions
source('r/helpers.R')

# establish connection
con <- moasdb_connect()

j <- DBI::dbExecute(con, 
                    read_sql("sql/init_db.sql"))

start <- Sys.time()

populate_core(con)
populate_table("long", con)
populate_table("repeated", con)
populate_table("cross", con)

spent <- as.numeric(round(Sys.time() - start, 3))
spent <- dplyr::case_when(
  spent < 10 ~ crayon::green(spent),
  spent > 30 ~ crayon::red(spent),
  TRUE ~ crayon::yellow(spent)
)

cat("\n ---------- \n")
cat_table_success(TRUE,
                  crayon::bold("Database populated in", spent, "minutes"))

