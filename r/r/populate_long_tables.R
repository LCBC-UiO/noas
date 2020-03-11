# Populate longitudinal tables
library(tidyverse)

# get helper functions
source('r/helpers.R')

# establish connection
con <- moasdb_connect()

db_dir <- "/tsd/p23/data/durable/tmp/db_clean_data_tmp/long/ehi/"

ffiles <- list.files(db_dir, "tsv$", full.names = TRUE)

ft <- lapply(ffiles, read_dbtable)
ft <- lapply(ft, dplyr::rename_all, .funs = function(x) gsub("ehi", "", x))
ft <- lapply(ft, dplyr::mutate_at, 
             .vars = dplyr::vars(starts_with("_")), 
             .funs = as.character)

# lapply(ft[[5]], insert_table_long, con = con, table_name = "ehi")
insert_table_long(ft[[1]], con = con, table_name = "ehi")
insert_table_long(ft[[5]], con = con, table_name = "ehi")

# 
# load("/tsd/p23/data/durable/MOAS/data/MOAS.RData")
# # Get legacy data
# MOAS <- MOAS %>% 
#   rename(subject_id = CrossProject_ID,
#          project_id = Project_Name,
#          wave_code = Project_Wave) %>% 
#   mutate(subject_id = as.integer(as.character(subject_id)))
# 
# 
# # BDI ----
# submit_long_table(MOAS, 
#                   dplyr::starts_with("BDI"), 
#                   !is.na(BDI), 
#                   "q_bdi")
# 
# 
#   dplyr::select(MOAS, 
#                      subject_id,
#                      project_id,
#                      wave_code,
#                      dplyr::starts_with("BDI")) %>% 
#     plyr::filter(x, !is.na(BDI)) %>% 
#     dplyr::rename_all(x, tolower) %>% 
#     
# 
# # PSQI ----
# submit_long_table(MOAS, 
#                   dplyr::starts_with("PSQI"), 
#                   !is.na(PSQI_01), 
#                   "q_psqi")
# 
# 
# # GDS ----
# submit_long_table(MOAS, 
#                   starts_with("GDS"), 
#                   !is.na(GDS), 
#                   "q_gds")
# 
# 
# # EHI ----
# submit_long_table(MOAS, 
#                   starts_with("EHI"), 
#                     !is.na(EHI_01), 
#                   "q_ehi")
# 
