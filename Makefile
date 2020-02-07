BASEDIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
include config_default.txt
-include config.txt

all: 3rdparty

.PHONY: dbstart
dbstart: ${DBDATADIR}/postgresql.conf
	3rdparty/postgresql/bin/pg_isready -h localhost -p $(DBPORT) -d lcbcdb || 3rdparty/postgresql/bin/pg_ctl -D ${DBDATADIR} -l ${DBLOGFILE} -w start && echo ok

.PHONY: dbstop
dbstop:
	3rdparty/postgresql/bin/pg_ctl -D ${DBDATADIR} stop

.PHONY: 
dberase:
	3rdparty/postgresql/bin/pg_ctl -D ${DBDATADIR} stop || true
	$(RM) -r ${DBDATADIR}

.PHONY: 3rdparty
3rdparty:
	$(MAKE) -C 3rdparty

${DBDATADIR}/postgresql.conf: 3rdparty
	bash bin/dbinit.sh

.PHONY: distclean
distclean:
	$(MAKE) -C 3rdparty clean


