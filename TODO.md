# TODO


## features
  * r/db/webui: support query with snapshots
    * Idea - git-hash as db-namespace:
      * supply git-hash as argument for import script
      * import script writes to namespace (use "latest" as default) 
      * in webui: show list of git-hashes + possiblility to select hash for query 
      * whenever data is exported, include git-hash (for example as part of filename)
      * 
  * write metadata: set column "id" and "type" in json 
    * no "idx" and "title"
  * reading metadata: setting types in db 
    * expand types, currently only int, float, text and date
    * time is imported as integer currently
    * "duration" type => "as.character" fo now?
    * move metadata setting to SQL instead
  * r/sql: how to handle undefined visits for long/repeated?
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
  * add db connection info to "show sql query"
    * add read-only user?

## bugs
  * mri/repeated: double underscore (`__`) before "site_name" column name

    
## potential problems
  * r/sql: how to connect multiple repeated tables?
    * problem: without referencing each others visit_id, the query will split their data into separate rows
  * name conflicts
    * sql: if table id is used more than once (for example in long and repeated)
    * sql: if table name is sql keyowrd?
    * webui: if table name machtes other html ids ("options_..")

