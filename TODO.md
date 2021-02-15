
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
    * can we refractor them to use let DB run them? <-- ie translate to sql?
  * visits table:
    * timepoint: column of computed sequential visit number
    * original_id: column of id assigned at time of collection, as subject_id is not what people will find in old documents and data. Important for matching older, currently not harmonised data to correct data in the db.
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
  * `_noas.json` is an array of a single object - array can be removed?

## bugs
  * dbimport/sql: columns need to be in same order for all tables of a specific type
    * alter insert_table.R to check for this before import
    * currently fails on meta-data setting, cause data of different type are in the same cols
 
## potential problems
  * dbimport/sql: how to connect multiple repeated tables?
    * problem: without referencing each others visit_id, the query will split their data into separate rows
  * name conflicts
    * sql: if table id is used more than once (for example in long and repeated)
    * sql: if table name is sql keyword?

