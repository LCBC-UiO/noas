# TODO

  * write metadata: set column "id" and "type" in json 
    * no "idx" and "title"
  * reading metadata: setting types in db 
    * can be dne by setting data.frame column types in R before pushng to db
    * start with float, int? 
    * "duration" type => "as.character" fo now?
  * remove column prefix in data TSVs
    * add "_" if first character is not in [A-Za-z]
    * when reading into DB: add "_" if first character is not '_'
  * r/sql: how to handle undefined visits for long/repeated?
    * currently, rows are silently discarded if (subj_id, project_id, wave_code) is not defined in core
  * compute derived data
    * currently some MOAS data is derived from raw data based on r-functions in two packages:
      * https://github.com/LCBC-UiO/Questionnaires
      * https://github.com/LCBC-UiO/Conversions
    * can we refractor them to use let DB run them?

    
potential problems:
  * r/sql: how to connect multiple repeated tables?
    * problem: without referencing each others visit_id, the query will split their data into separate rows
  * name conflicts
    * sql: if table id is used more than once (for example in long and repeated)
    * sql: if table name is sql keyowrd?
    * webui: if table name machtes other html ids ("options_..")

