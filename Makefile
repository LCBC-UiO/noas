BASEDIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

include config_default.txt
-include config.txt

simg_modules := \
	moas-r \
	moas-flask
include singularity/make_simg.mk

all: 3rdparty

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
3rdparty:
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
run_webui:
	singularity exec singularity/moas-flask.simg bash webui/start.sh

.PHONY: run_db
run_db: ${DBDATADIR}/postgresql.conf
	3rdparty/postgresql/bin/pg_isready -h localhost -p $(DBPORT) -d $(DBNAME) && $(MAKE) dbstop || true
	3rdparty/postgresql/bin/postgres -D $(DBDATADIR) -h 0.0.0.0 -p $(DBPORT)


.PHONY: pyenv
pyenv:
	python3 -m virtualenv env

.PHONY: pydeps
pydeps: pyenv
	bash -c "\
		source env/bin/activate \
	    && pip3 install -r requirements.txt \
	"

.PHONY: pyenv_webui
pyenv_webui: pyenv
	bash -c "\
		source env/bin/activate \
	    && bash webui/start.sh \
	"