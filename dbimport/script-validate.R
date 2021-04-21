#!/usr/bin/env Rscript
# get helper functions
source("dbimport/funcs-utils.R", echo = FALSE)

args = commandArgs(trailingOnly=TRUE)
ll <- length(args)
if(any("--help" %in% args)){
  cat("\n\nCommand to validate NOAS tables\n\n",
      "Requires a path to a folder containing table(s) for validation, where tables should be tab separated, have the same number of columns etc.\n",
      "Use: sh bin/validate_table [path/to/dir]\n",
      "example: bin/validate_table test_data/ehi\n\n")
  
}else if(ll == 0){
  cat("Path to a folder must be provided\n use --help if you are uncertain about the arguments.\n")
}else{
  for(tab_id in args){
    cat(tab_id, "\t")
    # expand file path to full
    path <- normalizePath(tab_id)
    if(!dir.exists(path)){
      cat("Directory does not exist:\t" , path)
    }else{
      cur_file_list <- list.files(path)
      fail_if(!"_noas.json" %in% cur_file_list, 
              "There is no _noas.json for table ", tab_id)
      noas_j <- read_file(file.path(path, "_noas.json"))
      cur_file_list <- setdiff(cur_file_list, "_noas.json")
      if("_metadata.json" %in% cur_file_list){
        metadata_j <- read_file(file.path(path, "_metadata.json"))
        cur_file_list <- setdiff(cur_file_list, "_metadata.json")
      }
      check_tsvs(cur_file_list, path)
      cat("Table passes initial validation.\n")
    }
  }
}

cat("\n")
