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
        sql <- sprintf("UPDATE metatables SET %s = $1 WHERE id = $2", field)
        # has field?
        if (is.null(meta_info$jsn[[field]])) {
          next()
        }
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
      # add metacolumns
      if(all(c(!is.null(meta_info$jsn$columns), 
              nrow(meta_info$jsn$columns) > 0))){
        if (!alter_cols(meta_info, con)) {
          stop("insert_metadata column type");
        }
      }
      return(T)
    }, error=function(e) {
      cat(sprintf("error: %s", e))
      return(F)
    }
  )
  invisible(ok)
}

alter_cols <- function(meta_info, con){
  sql_tab = sprintf("ALTER TABLE %s_%s", 
                    meta_info$table_type, meta_info$id)
  
  sql_cols <- mapply(
    sprintf, 
    meta_info$jsn$columns$id,
    meta_info$jsn$columns$type,
    meta_info$jsn$columns$id,
    meta_info$jsn$columns$type,
    MoreArgs = list(
      # Need the USING part because all columns are imported as string at first
      # https://stackoverflow.com/questions/13170570/change-type-of-varchar-field-to-integer-cannot-be-cast-automatically-to-type-i
      fmt = 'ALTER COLUMN "_%s" TYPE %s USING (_%s::%s)'
    )
  )
  
  sql_cmd <- paste(sql_tab, 
                   paste(sql_cols, collapse = ", "), 
                   ";", sep = " ")
  
  k <- DBI::dbExecute(con, sql_cmd)
  k <- ifelse(k == 1, TRUE, FALSE)
  invisible(k)
}

fix_metadata <- function(table_dir, con) {
  
  # get meta-data
  meta_info <- read_metadata(table_dir)
  
  # add meta-data
  j <- insert_metadata(meta_info, con) 
  cat_table_success(j, sprintf("metadata\t%s\tadded\t ", basename(table_dir)))
}
