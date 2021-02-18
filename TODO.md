
## priority list  
  * fixing long table names
  * fix old data so they pass new validation

## features
  * support PGS data: should be dynamically computed for 
  * reading metadata: setting types in db 
    * expand types, currently only integer, float, text and date
      * bool?
    * time is imported as integer currently
    * "duration" type => "as.character" for now?
  * dbimport/sql: how to handle undefined visits for long/repeated?
    * currently, rows are silently discarded if (subj_id, project_id, wave_code) is not defined in core
  * compute derived data
    * currently some MOAS data is derived from raw data based on r-functions in two packages:
      * https://github.com/LCBC-UiO/Questionnaires
      * https://github.com/LCBC-UiO/Conversions
    * can we refractor them to let DB run them?
  * visits table:
    * timepoint: column of computed sequential visit number
  * other core-like tables
    * table with project_id and wave_code information (like test versions etc)
    * table with information on MRI scanners
  * meta-data: add checks for validation of cell values within known correct values (enum)
  * dbimport/sql/webui: write non-critical errors/warnings to metadata
    * number of omitted rows
    * exceptions when importing metadata
    * show warnings for each table in web UI

## cleanup/refactoring
  * dbimport: use tryCatch for error handling?
  * dbimport: check if metadata fields are known; error on unknown keys
    * example: for all keys `if (key %in% c("title", "category", "descr")) {...} else { stop(...) }`
  * data/import: remove quotes from strings 
  * data: remove pgs from the git data history
    * and symlink pgs like mri
  * dbimport: log verbosity when adding large number of repeated tables
    * the data are already in single subject/wave files, so adding them this way to the DB would be convenient
    * this floods the import log though.

## bugs
  * webui: fourth column for repeated tables should appear as the first column.
  
## potential problems
  * dbimport/sql: how to connect multiple repeated tables?
    * problem: without referencing each others visit_id, the query will split their data into separate rows
  * name conflicts
    * sql: if table name is sql keyword?

