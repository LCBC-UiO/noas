source("dbimport/funcs-utils.R", echo = FALSE)

read_metadata_str <- function(dirpath){
  ffile <- file.path(dirpath, "_metadata.json")
  if (!file.exists(ffile)) return(NULL)
  return(readChar(ffile, file.size(ffile)))
}

fix_metadata <- function(table_dir, con) {
  jsn_str <- read_metadata_str(table_dir);
  if (is.null(jsn_str)) return()
  table_id <- basename(table_dir)
  DBI::dbExecute(con, "select import_metadata($1, $2);", params=list(table_id, jsn_str))
  cat_table_success(j, sprintf("metadata\t%s\tadded\t ", basename(table_dir)))
}
