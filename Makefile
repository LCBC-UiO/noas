BASEDIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

include config_default.txt
-include config.txt

all: 3rdparty

simg_modules := \
	moas-r 
include singularity/make_simg.mk

websrcs := \
	webui/www/css/bootstrap-theme.css \
	webui/www/css/bootstrap.css \
	webui/www/css/bootstrap.min.css \
	webui/www/css/bootstrap.min.css.map \
	webui/www/css/tabulator.min.css \
	webui/www/js/bootstrap.min.js \
	webui/www/js/fontawesome.min.js \
	webui/www/js/jquery.min.js \
	webui/www/js/popper.min.js \
	webui/www/js/solid.min.js \
	webui/www/js/tabulator.min.js \
	webui/www/js/xlsx.full.min.js

webui/www/%:
	echo $*.gz $@
	zcat 3rdparty/$*.gz > $@ 


.PHONY: dbstart
dbstart: ${DBDATADIR}/postgresql.conf
	3rdparty/postgresql/bin/pg_isready -h localhost -p $(DBPORT) -d ${DBNAME} || 3rdparty/postgresql/bin/pg_ctl -D ${DBDATADIR} -l ${DBLOGFILE} -w start && echo ok

.PHONY: dbstop
dbstop:
	3rdparty/postgresql/bin/pg_ctl -D ${DBDATADIR} stop

.PHONY: 
dberase:
	3rdparty/postgresql/bin/pg_ctl -D ${DBDATADIR} stop || true
	$(RM) -r ${DBDATADIR}

.PHONY: 3rdparty
3rdparty: $(websrcs)
	$(MAKE) -C 3rdparty

${DBDATADIR}/postgresql.conf: 3rdparty
	bash bin/dbinit.sh

.PHONY: distclean
distclean:
	$(MAKE) -C 3rdparty clean


.PHONY: run_dbimport
run_dbimport:
	singularity exec singularity/moas-r.simg bash bin/dbpopulate.sh

.PHONY: run_webui
run_webui: 3rdparty
	PORT=$(WEBSERVERPORT) \
	DOCROOT=$(BASEDIR)/webui/www \
	BASEDIR=$(BASEDIR) \
	DBHOST=$(DBHOST) \
	DBPORT=$(DBPORT) \
	DBNAME=$(DBNAME) \
	DBUSER=$(DBUSER) \
	3rdparty/lighttpd/sbin/lighttpd -D -f lighttpd.conf

.PHONY: run_db
run_db: ${DBDATADIR}/postgresql.conf
	3rdparty/postgresql/bin/pg_isready -h localhost -p $(DBPORT) -d $(DBNAME) && $(MAKE) dbstop || true
	3rdparty/postgresql/bin/postgres -D $(DBDATADIR) -h 0.0.0.0 -p $(DBPORT)
