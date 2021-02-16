
## priority list  
  * fixing long table names
  * fix old data so they pass new validation
  * alt_subj_id
  * reduce underscores in tables names
  * data/import: remove quotes from strings 
  * dbimport: check if metadata fields are known; error on unknown keys
  * data/import: remove quotes from strings 
    * also force read to quote = FALSE
  * look at import warnings - maybe error on warning setting for import

## features
  * support PGS data: should be dynamically computed for 
  * write metadata: set column "id" and "type" in json 
    * no "idx" and "title"
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
    * can we refractor them to use let DB run them?
  * visits table:
    * alt_subj_id: column of id assigned at time of collection, as subject_id is not what people will find in old documents and data. Important for matching older, currently not harmonised data to correct data in the db. Give `NA` if it doesnt have any.
  * other core-like tables
    * table with project_id and wave_code information (like test versions etc)
    * table with information on MRI scanners
  * meta-data: add checks for validation of cell values within known correct values
  * dbimport/sql/webui: write non-critical errors/warnings to metadata
    * number of omitted rows
    * exceptions when importing metadata
    * show warnings for each table in web UI
  * dbimport/sql: maybe a `???_noas_data_src` field for every non_core table (`???`)? 
  * dbimport: import the folders by modification date (instead alphabetically) to fail early on breaking changes

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
    * sql: if table id is used more than once (for example in long and repeated)
    * sql: if table name is sql keyword?

