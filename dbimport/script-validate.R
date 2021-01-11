# get helper functions
source('dbimport/funcs-validate.R')

args = commandArgs(trailingOnly=TRUE)
ll <- length(args)

cat(args)
if(args == "--help"){
  cat("\n\nCommand to validate NOAS tables\n\n",
      "Requires a path to a folder containing table(s) for validation, where tables should be tab separated, have the same number of columns etc.\n",
      "Use: sh bin/validate_table [path/to/dir]\n",
      "example: bin/validate_table test_data/long/ehi\n\n")
  
}else if(ll == 0){
  cat("Path to a folder must be provided\n use --help if you are uncertain about the arguments.\n")
}else{
  # expand file path to full
  path <- normalizePath(args[1])
  if(!dir.exists(path)){
    cat("Directory does not exist:\t" , path)
  }else{
    validate_tables(path)
  }
}

cat("\n")
