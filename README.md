
# NOAS 

## Quick start

  *  Clone the repository and change into directory  
     `# git clone .. && cd ..`
  *  Build or copy the singularity images 
     (Note: If you have all R and Python3 dependences installed, your can
     skip this step.)   
    * With internet connection:  
      `make prepare_offline_simg`
    * Without internet connection (TSD):  
      Copy `moas-flask.simg` and `moas-r.simg` into `./singularity/`
  * Edit configuration (choose ports that are not in use!)  
     `cp config_default config.txt` and edit `config.txt`
  * Start database  
    `make dbstart` (use `make dberase` to reset the DB)
  * Import data  
    `make run_dbimport`
    (Note: if R deps are installed, you can call `bin/dbpopulate.sh` directly)
  * Start web UI  
    `make run_webui`
    (Note: if Python3 deps are installed, you can call `webui/start.sh` directly)

## Requirements
  * make
  * (singularity)
  * (docker)

## Local database

  * Edit configuration (change port!):  
    `cp config_default config.txt` and edit `config.txt`  
    Edit config before first start of DB (call `dberase` otherwise).
  * Start database:  
    `make dbstart`
  * Stop database:  
    `make dbstop`
  * Stop database and delete all data:  
    `make dberase`
