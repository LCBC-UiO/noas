
## priority list  


## features
  * reading metadata: setting types in db 
    * expand types, currently only integer, float, text and date
      * bool?
  * support PGS data: should be dynamically computed for 
    * time is imported as integer currently
    * "duration" type => "as.character" for now?
  * dbimport/sql/webui: write non-critical errors/warnings to metadata
    * number of omitted rows
    * exceptions when importing metadata
    * show warnings for each table in web UI
  * compute derived data
    * currently some MOAS data is derived from raw data based on r-functions in two packages:
      * https://github.com/LCBC-UiO/Questionnaires
      * https://github.com/LCBC-UiO/Conversions
  * other core-like tables
    * table with project_id and wave_code information (like test versions etc)
    * table with information on MRI scanners
  * meta-data: add checks for validation of cell values within known correct values (enum)


## cleanup/refactoring
  * dbimport: use tryCatch for error handling?
  * data: remove pgs from the git data history
    * and symlink pgs like mri

## bugs
  * webui: fourth column for repeated tables should appear as the first column. (idx = -1?)
  
## potential problems
  * Repeated fourth table: can we have a way for it to always be selected (to be sure rows are distinguishable)
    * how to not to duplicate?
