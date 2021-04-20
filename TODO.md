
## priority list  
- make SQL add underscore for non-primary key columns during import

## features
  * other core-like tables
    * table with project_id and wave_code information (like test versions etc)
    * table with information on MRI scanners


## cleanup/refactoring
  * dbimport: use tryCatch for error handling?
  * data: remove pgs from the git data history
    * and symlink pgs like mri

## bugs

## potential problems
  * Repeated fourth table: can we have a way for it to always be selected (to be sure rows are distinguishable)
    * how to not to duplicate?
