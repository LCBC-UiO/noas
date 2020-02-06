# Populate longitudinal tables
library(tidyverse)

# get helper functions
source('r/helpers.R')

# establish connection
con <- moasdb_connect()

# Get legacy data
load("/tsd/p23/data/durable/MOAS/data/MOAS.RData")
MOAS <- MOAS %>% 
  rename(subject_id = CrossProject_ID,
         project_id = Project_Name,
         wave_code = Project_Wave) %>% 
  mutate(subject_id = as.integer(as.character(subject_id)))


# BDI ----
submit_long_table(MOAS, 
                  dplyr::starts_with("BDI"), 
                  !is.na(BDI), 
                  "q_bdi")


# PSQI ----
submit_long_table(MOAS, 
                  dplyr::starts_with("PSQI"), 
                  !is.na(PSQI_01), 
                  "q_psqi")


# GDS ----
submit_long_table(MOAS, 
                  contains("GDS"), 
                  !is.na(GDS), 
                  "q_gds")


# EHI ----
submit_long_table(MOAS, 
                  contains("EHI"), 
                  !is.na(EHI_01), 
                  "q_ehi")
