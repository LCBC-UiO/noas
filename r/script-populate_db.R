
# get helper functions
source('r/funcs-utils.R')
source('r/funcs-populate.R')

args <- commandArgs(trailingOnly = TRUE)
if(length(args) > 0) args <- match.arg(args, c("unicode", "ascii"))

unicode <- if(!isatty(stdout())||length(args) == 0||args == "unicode"){ TRUE }else{ FALSE }

# establish connection
con <- moasdb_connect()

j <- DBI::dbExecute(con, 
                    read_sql("sql/init_db.sql"))

start <- Sys.time()

populate_core(con, unicode = unicode)
populate_table("long", con, unicode = unicode)
populate_table("repeated", con, unicode = unicode)
populate_table("cross", con, unicode = unicode)

spent <- round(as.numeric(Sys.time() - start, units="mins"), 3)


spent <- (function(){
  if (spent < 5)  return(codes(unicode)$success(spent))
  if (spent > 10) return(codes(unicode)$fail(spent))
  return(codes(unicode)$note(spent))
})()

cat("\n ---------- \n")
cat_table_success(TRUE,
                  codes(unicode)$bold("Database populated in", spent, "minutes"),
                  unicode = unicode)

