
# NOAS 

## Quick start

  * Clone the repository and change into directory  
     `git clone ... && cd ...`
  * Build or copy the singularity images  
    (Note: If you have all R dependences installed, your can
     skip this step.)
    * With internet connection:  
      `make prepare_offline_simg`
    * Without internet connection (TSD):  
      Copy `moas-r.simg` into `./singularity/`
  * Edit configuration 
    (set `DBPORT` and `WEBSERVERPORT` to a port that is not in use!)  
     `cp config_default.txt config.txt` and edit `config.txt`
  * Start database  
    `make dbstart` (use `make dberase` to reset the DB)
  * Import data  
    `make run_dbimport`  
    (Note: If all  R deps are installed, you can call `bin/dbpopulate.sh` directly)
  * Start web UI  
    `make run_webui`

## Requirements
  * build tools (gcc, make, ...)
  * (singularity for R deps)
  * (docker for R deps)

## Dev

## supported column types 

These data type are supported as NOAS table columns (in metadata, DB and web UI).

  * `text`
  * `float`
  * `int`
  * `date`