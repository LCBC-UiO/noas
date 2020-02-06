# Populate core tables
# Populate longitudinal tables
library(tidyverse)

# get helper functions
source('r/helpers.R')

# establish connection
con <- moasdb_connect()

# Get legacy data
load("/tsd/p23/data/durable/MOAS/data/MOAS.RData")
MOAS <- MOAS %>% 
  mutate(CrossProject_ID = as.integer(as.character(CrossProject_ID)))


# project table ----
MOAS %>% 
  transmute(
    id = Project_Name, 
    code = Project_Number) %>% 
  distinct() %>% 
  arrange(code) %>% 
DBI::dbWriteTable(con, "project", ., 
                  append = TRUE, row.name = FALSE)

# subject table ----
tmp <- MOAS %>% 
  transmute(
    id = CrossProject_ID, 
    sex = Sex,
    birthdate = Birth_Date) %>% 
  distinct() %>% 
  arrange(id) %>% 
DBI::dbWriteTable(con, "subject", ., 
                  append = TRUE, row.name = FALSE)

## wave table
tmp <- MOAS %>% 
  transmute(
    project_id = Project_Name,
    code = Project_Wave
  ) %>% 
  distinct() %>% 
  arrange(project_id, code) %>% 
DBI::dbWriteTable(con, "wave", ., 
                  append = TRUE, row.name = FALSE)


# visits table ---
MOAS %>% 
  transmute(
    subject_id = CrossProject_ID, 
    project_id = Project_Name,
    wave_code = Project_Wave,
    visitdate = Test_Date
  ) %>% 
  distinct() %>% 
  arrange(subject_id) %>% 
DBI::dbWriteTable(con, "visit", ., 
                  append = TRUE, row.name = FALSE)
