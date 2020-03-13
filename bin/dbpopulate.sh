#!/bin/bash

Rscript r/db_start.R
Rscript r/populate_core_tables.R
Rscript r/populate_long_tables.R