declare  BASEDIR; BASEDIR="$( cd "$( dirname $0 )/.." && pwd )"
source config_default.txt
[ -f config.txt ] && source config.txt

mkdir -p ${DBDATADIR}
mkdir -p ${DBLOGFILE%/*}

[ -z "$(ls ${DBDATADIR})" ] || { printf "skipping db init\n" >&2; exit 0; }
3rdparty/postgresql/bin/pg_ctl initdb -D ${DBDATADIR}


cat > ${DBDATADIR}/postgresql.conf << EOI 
port = ${DBPORT}
max_connections = 100                   # (change requires restart)
shared_buffers = 128MB                  # min 128kB
max_locks_per_transaction = 1024        # might need increase while NOAS grows
log_timezone = 'Europe/Oslo'
datestyle = 'iso, mdy'
timezone = 'Europe/Oslo'
lc_messages = 'en_US.UTF-8'                     # locale for system error message
lc_monetary = 'en_US.UTF-8'                     # locale for monetary formatting
lc_numeric = 'en_US.UTF-8'                      # locale for number formatting
lc_time = 'en_US.UTF-8'                         # locale for time formatting
default_text_search_config = 'pg_catalog.english'
EOI
3rdparty/postgresql/bin/pg_ctl -D ${DBDATADIR} -l ${DBLOGFILE} -w start
3rdparty/postgresql/bin/createuser -s ${DBUSER} -h localhost -p ${DBPORT} 2> /dev/null
3rdparty/postgresql/bin/createdb -O ${DBUSER} ${DBNAME} -h localhost -p ${DBPORT} 2> /dev/null
