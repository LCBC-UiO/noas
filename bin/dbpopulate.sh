#!/bin/bash

table_dir='test_data'

Rscript r/db_start.R
Rscript r/populate_core_tables.R $table_dir/core
Rscript r/populate_long_tables.R $table_dir/long