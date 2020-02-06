# Populate longitudinal tables
library(tidyverse)

# get helper functions
source('r/helpers.R')

# establish connection
con <- moasdb_connect()


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