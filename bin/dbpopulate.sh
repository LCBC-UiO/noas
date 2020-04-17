#!/bin/bash

Rscript r/db_start.R
Rscript r/populate_core_tables.R
Rscript r/populate_cross_tables.R
Rscript r/populate_long_tables.R
Rscript r/populate_repeated_tables.R