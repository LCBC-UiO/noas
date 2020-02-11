




## local database

* Edit configuration (change port!):  
`cp config_default config.txt` and edit `config.txt`  
Edit config before first start of DB (call `dberase` otherwise).
* Start database:  
`make dbstart`
* Stop database:  
`make dbstop`
* Stop database and delete all data:  
`make dberase`
