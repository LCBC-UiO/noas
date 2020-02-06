library(tidyverse)
load("data/MOAS.RData")
MOAS <- MOAS %>% 
  mutate(CrossProject_ID = as.integer(as.character(CrossProject_ID)))

con <- DBI::dbConnect(RPostgreSQL::PostgreSQL(), #":memory:",
                      user="dbuser", 
                      dbname="lcbcdb", 
                      host="localhost")


k <- readr::read_file("scripts/init_db.sql")


DBI::dbExecute(con, k)

# Make some tables ----

## project table
tmp <- MOAS %>% 
  transmute(
    id = Project_Name, 
    code = Project_Number) %>% 
  distinct() %>% 
  arrange(code)

DBI::dbWriteTable(con, "project", tmp, 
                  append = TRUE, row.name = FALSE)

## subject table
tmp <- MOAS %>% 
  transmute(
    id = CrossProject_ID, 
    sex = Sex,
    birthdate = Birth_Date) %>% 
  distinct() %>% 
  arrange(id)

DBI::dbWriteTable(con, "subject", tmp, 
                  append = TRUE, row.name = FALSE)

## wave table
tmp <- MOAS %>% 
  transmute(
    project_id = Project_Name,
    code = Project_Wave
  ) %>% 
  distinct() %>% 
  arrange(project_id, code)

DBI::dbWriteTable(con, "wave", tmp, 
                  append = TRUE, row.name = FALSE)


## visits table
tmp <- MOAS %>% 
  transmute(
    subject_id = CrossProject_ID, 
    project_id = Project_Name,
    wave_code = Project_Wave,
    visitdate = Test_Date
  ) %>% 
  distinct() %>% 
  arrange(subject_id)

DBI::dbWriteTable(con, "visit", tmp, 
                  append = TRUE, row.name = FALSE)


tmp <-MOAS %>% 
  select(CrossProject_ID,
         Project_Name,
         Project_Wave,
         contains("PSQI")) %>% 
  rename(subject_id = CrossProject_ID,
         project_id = Project_Name,
         wave_code = Project_Wave) %>% 
  filter(!is.na(PSQI_01)) %>% 
  mutate(subject_id = subject_id) %>% 
  rename_all(tolower) %>% 
  distinct()

DBI::dbWriteTable(con, "tmp_q_psqi", tmp, 
                  #append = TRUE, 
                  temporary = TRUE,
                  overwrite = TRUE,
                  row.name = FALSE)

# test instert template
read_sql <- function(path){
  readChar(path, file.info(path)$size)
}






insert_table <- function(x, dbcon, 
                         table_name, 
                         template_path = "scripts/insert_table.sql"){
  
  tryCatch({
    k <- DBI::dbWriteTable(
      dbcon, 
      paste0("tmp_", table_name), 
      x, 
      #append = TRUE, 
      temporary = TRUE,
      overwrite = TRUE,
      row.name = FALSE
    )
    
    if(k == FALSE) stop("tmp table not initiated",
                        call. = FALSE)
    
    template <- read_sql(template_path)
    tmp_template <- gsub("\\{table_name\\}", 
                         table_name, template)
    
    
    DBI::dbExecute(dbcon, tmp_template)
  },  
  finally = DBI::dbExecute(
    dbcon,
    paste0("drop table if exists tmp_",
           table_name,";")
  )
  )
  
  cat("Table added sucessfully")
}



tmp <- MOAS %>% 
  select(CrossProject_ID,
         Project_Name,
         Project_Wave,
         contains("BDI")) %>% 
  rename(subject_id = CrossProject_ID,
         project_id = Project_Name,
         wave_code = Project_Wave) %>% 
  filter(!is.na(BDI)) %>% 
  mutate(subject_id = subject_id) %>% 
  rename_all(tolower) %>% 
  distinct()

insert_table(x = tmp, dbcon = con,
             "q_bdi")



# Testing functionality 

k <- DBI::dbSendQuery(con, "select * from visit v
left join subject on subject.id = v.subject_id
left join wave on wave.code = v.wave_code and wave.project_id = v.project_id
left join project on project.id = v.project_id
left join q_bdi on q_bdi.subject_id = v.subject_id and q_bdi.wave_code = v.wave_code and q_bdi.project_id = v.project_id
")


df <- DBI::dbFetch(k)

tbl(con, "visit") 

tbl(con, "subject")


tbl(con, "visit") %>% 
  left_join(tbl(con, "subject") %>% 
              mutate(subject_id = id)) %>% 
  left_join(tbl(con, "q_bdi")) %>% 
  show_query()


# DBI::dbDisconnect(con)
