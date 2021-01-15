# Data explanations

## Core data
Upon attempting to import data, no core data should be omitted.
If the dbimport diagnostic printouts indicate that there is core data being omitted, something is wrong during import logic.

### subjects
Main list of unique participants in the data-base.
This is the primary look-up table for futher import of data, a subject must exist in this table for other data to be imported.

Table must include:
- `id`  - a column with the 7-digit LCBC participant identifiers
- `shareable` - a column specifyin how the participants data may be handled (`1`, `0`, `NA`)

Should include:
- `sex`  - biological sex of participant
- `birthdate` - birthdate of participant


### projects
Main list of projects in the data-base.
This is the primary look-up table for further import of longitudinal and repeated data.

Table must include:
- `id`  - a column with the project acronym
- `code` - a column with the project number

Future data might include:
- `name`  - Full name of project

### waves
A secondary project overview, specifying the longitudinal collection times (waves) for each project.
A project must exist in the projects file, for the waves to be included. 
The data import will fail if a project is specified in the waves file and not in the projects file.

Table must include:
- `project_id`  - a column with the project acronym as specified in the projects file
- `code` - a column with the wave code number

Future data might include:
- `startdate` - date where data-collection for this wave started  
- `enddate` - date where data-collection for this wave ended  

### visits
The visits table if the final core table, where information from the other core-tables are necessary for successful import.

A visit can only be valid if:

- the subject is in the subjects-table  
- the project is in the projects-table  
- the wave is in the waves-table  

Table must include:
- `subject_id` - a column with the 7-digit LCBC participant identifiers
- `project_id`  - a column with the project acronym as specified in the projects file
- `wave_code` - a column with the wave code number

Table should include:
- `visitdate` - date of first visit, either first test or MRI session

Future data might include:
- `original_subject_id` - some participants have had several ids as they have joined multiple projects, this could help keep track of what id was used during data collection of a particular wave, in case some data has not been renamed.

## Non-core data
All other data that is not the four core tables.
Cognitive variables, MRI summary statistics, genetic data, PGS, questionnaires etc. 
Essentially all research data. 

These are again grouped into 3 types of data:

- cross-sectional - where there is a single observation per participant  
- longitudinal - where the data is sampled over time, but only once per wave   
- repeated  - where data is sampled several times within a single wave (like time series)  

### Longitudinal
Longitudinal data is data collected over time, in the data-base this means collected over several waves of data collection. 
This is the most common type of raw data in the data-base, and most cognitive and questionnaire data are longitudinal data. 

Tables must include:
- `subject_id`
- `project_id`
- `wave_code`

And for every row, the combination of these need to exist in the visits-table to be imported in to the data-base. 

### Cross-sectional
There is only a single observation per participant. 
This is data where there is no current, planned or valid longitudinal data, so each participant can only have a single value.
Examples of this is PGS's and PET data.

Tables must include:
- `subject_id`

The values in this column must exist in the subjects-table to imported to the data-base.

### Repeated
Repeated data are an extension of longitudinal data. 
These are data where within a single wave of data-collection, multiple observations of the same variable are collected. 
Examples of such data are time-series data (from computerized-tests f.ex.).

Tables must include:
- `subject_id`
- `project_id`
- `wave_code`
- a forth column distinguishing the observations (in time-series often date, time or date-time)

And for every row, the combination of the first three columns need to exist in the visits-table to be imported in to the data-base. 
Secondly, the fourth column must uniquely distinguish each observation of data, duplication of the four necessary columns will result in import failure.
