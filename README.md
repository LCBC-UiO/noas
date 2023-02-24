
# NOAS 

## Quick start

  * Clone the repository and change into directory  
     `git clone ... && cd ...`
  * Edit configuration 
     `cp config_default.txt config.txt` and edit `config.txt`
    (set `DBPORT` and `WEBSERVERPORT` to a port that is not in use!)  
  * Start database  
    `make run_db` (you can use `make dberase` to reset the DB)  
    Open a new tab for the steps below.
  * Import data  
    `make run_dbimport` 
  * Start web UI  
    `make run_webui`

### Installing on TSD
  * Outside TSD: After cloning the repo, run `make prepare_offline`
  * Copy the whole directory into TSD and proceed with the steps above

### updating

  * run `make update` - it will pull changes and it will also place the git hash available for the web UI

## Requirements

  * build tools (gcc, make, ...)
  * R
  * git

## Dev

## Supported column types 

These data types are supported as NOAS table columns (in metadata, DB and web UI).

  * `text`
  * `float`
  * `integer`
  * `date`
  * `time` (HH:MM:SS)
  * `boolean`

