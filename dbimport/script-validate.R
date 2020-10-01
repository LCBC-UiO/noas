# get helper functions
source('dbimport/funcs-validate.R')

args <- commandArgs(trailingOnly = TRUE)

if(length(args) == 3){
  unicode <- if(args[3] == "unicode"){ "unicode" }else{ "ascii" }
}else{
  unicode <- if(isatty(stdout())){ "unicode" }else{ "ascii" }
}

ll <- length(args)
cat(args)
if(ll == 1 && args == "--help"){
  cat("\n\nCommand to validate NOAS tables\n\n",
      "Requires a path to a folder containing table(s) for validation, where tables should be tab separated, have the same number of columns etc.\n",
      "First argument is the path, second is the table type (one of cross/long/repeated). ",
      "A third optional argument may be given to indicate whether console output should be in unicode or ascii character encoding\n\n",
      "Use: sh bin/validate_table [path/to/dir] [type] [encoding]\n",
      "\nexample: bin/validate_table test_data/long/ehi long unicode\n\n")
  
}else if(ll == 0){
  cat("Path to a folder must be provided\n use --help if you are uncertain about the arguments.\n")
}else if(ll == 1){
  cat("Both a folder path and table type must be provided\n use --help if you are uncertain about the arguments.\n")
}else{
  # expand file path to full
  path <- normalizePath(args[1])
  if(!dir.exists(path)){
    cat("Directory does not exist:\t" , path)
  }else{
    validate_tables(path, args[2], unicode)
  }
}

cat("\n")
