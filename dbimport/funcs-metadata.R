source("dbimport/funcs-read.R", echo = FALSE)
source("dbimport/funcs-utils.R", echo = FALSE)

# meta data ----
#' Inserts meta-information to the DB
#' 
#' Insert meta-information provided
#' into the meta-information tables
#' in the database.
#' 
#' @param con database connection
#' @param meta_info information from \code{\link{get_metadata}}
insert_metadata <- function(meta_info, con){
  # has metadata?
  if (is.null(meta_info$jsn)) {
    return(T);
  }
  ok <- tryCatch(
    {
      # add metatables
      valid_jsn_fields <- c("title", "category", "descr")
      for (field in valid_jsn_fields) {
        # has field?
        if (is.null(meta_info$jsn[[field]])) {
          next()
        }
        sql <- sprintf("UPDATE metatables SET %s = $1 WHERE id = $2", field)
        params <- list(
          meta_info$jsn[[field]],
          meta_info$id
        )
        if (DBI::dbExecute(con, sql, params=params) != 1) {
          stop(
            sprintf("insert_metadata metatables table=%s field=%s value=%s",
              meta_info$id,
              field,
              meta_info$jsn[[field]]
            )
          )
        }
      }
      # loop over all columns - if columns is NULL, this will do nothing
      for (i in 1:length(meta_info$jsn$columns)) {
        mc <- meta_info$jsn$columns[[i]]
        # needs id
        if (is.null(mc[["id"]])) {
          stop(sprintf("insert_metadata table=%s missing id in column=%d",
            meta_info$id,
            i
          ))
        }
        # set column type?
        if (!is.null(mc[["type"]])) {
          alter_col(con, meta_info$id, meta_info$table_type, mc$id, mc$type)
        }
        # set any of these fields in metacolumns
        valid_set_fields <- c("title", "descr", "type")
        for (mc_key in valid_set_fields) {
          # has field?
          if (is.null(mc[[mc_key]])) {
            next()
          }
          set_metacol(con, meta_info$id, mc[["id"]], mc_key, mc[[mc_key]])
        }
      }
      invisible(T)
    }, error=function(e) {
      cat(sprintf("error: %s\n", e$message))
      invisible(F)
    }
  )
  invisible(ok)
}

alter_col <- function(con, table_id, table_type, col_id, col_type){
  # Need the USING part because all columns are imported as string at first
  # https://stackoverflow.com/questions/13170570/change-type-of-varchar-field-to-integer-cannot-be-cast-automatically-to-type-i
  sql_cmd <- sprintf('ALTER TABLE %s_%s ALTER COLUMN "_%s" TYPE %s USING (_%s::%s);',
    table_type,
    table_id,
    col_id,
    col_type,
    col_id,
    col_type
  )
  k <- DBI::dbExecute(con, sql_cmd)
  k <- ifelse(k == 0, TRUE, FALSE) # the alter statement seems to update 0 rows
  invisible(k)
}

set_metacol <- function(con, table_id, col_id, key, value) {
  sql <- sprintf("UPDATE metacolumns SET %s = $1 WHERE metatable_id = $2 AND id = $3", key)
  if (DBI::dbExecute(con, sql, params=list(value, table_id, paste0("_", col_id))) != 1) {
    stop(
      sprintf("insert_metadata metacolumns table=%s column=%s key=%s value=%s",
        table_id,
        col_id,
        key,
        value
      )
    )
  }
  invisible(T)
}

fix_metadata <- function(table_dir, con) {
  
  # get meta-data
  meta_info <- read_metadata(table_dir)
  
  # add meta-data
  j <- insert_metadata(meta_info, con) 
  cat_table_success(j, sprintf("metadata\t%s\tadded\t ", basename(table_dir)))
}
