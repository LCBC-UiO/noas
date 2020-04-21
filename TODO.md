# TODO

  * r/sql/webui: support a category for each table
    * to get a better overvew in webui
    * can be done by 
      * sub-folder
      * info in metadata file
      * prefix for folder
  * r/sql/webui: get metadata from files, for all non-core tables
    * general info:
      * long name
      * description?
      * last update?
    * column specific info:
      * type of data
        * currently "text" for all columns
        * idea: start with "float" in addition
      * long name
      * description?
  * r/sql/webui: support MRI tables (long_* with one additional columns for primary key)
  * r/sql: how to handle undefined visits for long/repeated?
    * currently, rows are silently discarded if (subj_id, project_id, wave_code) is not defined in core
  * r/sql: how to connect multiple repeated tables?
    * problem: without referencing each others visit_id, the query will split their data into separate rows
    * cbind before importing?
  * data/test_data: rm NA-only rows? 
compute derived data
   * currently some MOAS data is derived from raw data based on r-functions in two packages:
      * https://github.com/LCBC-UiO/Questionnaires
      * https://github.com/LCBC-UiO/Conversions
  * can we refractor them to use let DB run them?

