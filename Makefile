BASEDIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

include config_default.txt
-include config.txt

websrcs := \
	webui/www/css/bootstrap.min.css \
	webui/www/css/bootstrap.min.css.map \
	webui/www/css/tabulator.min.css \
	webui/www/css/tabulator.min.css.map \
	webui/www/css/tabulator_bootstrap5.min.css \
	webui/www/css/tabulator_bootstrap5.min.css.map \
	webui/www/js/bootstrap.min.js \
	webui/www/js/bootstrap.min.js.map \
	webui/www/js/fontawesome.min.js \
	webui/www/js/jquery.min.js \
	webui/www/js/popper.min.js \
	webui/www/js/popper.min.js.map \
	webui/www/js/solid.min.js \
	webui/www/js/showdown.min.js \
	webui/www/js/tabulator.min.js \
	webui/www/js/tabulator.min.js.map \
	webui/www/js/xlsx.full.min.js \
	webui/www/js/pdfkit.standalone.js \
	webui/www/js/blob-stream.js \
	webui/www/js/d3.v6.min.js \
	webui/www/js/fuse-6.4.6.js

# ------------------------------------------------------------------------------

# build

all: 3rdparty webui/www/static_info.json

PHONY: prepare_offline
prepare_offline:
	$(eval TMPDIR := $(shell mktemp -d))
	DIR=${TMPDIR}/noas
	git clone ${BASEDIR} ${TMPDIR}/noas && \
		cd ${TMPDIR}/noas && \
		make -C 3rdparty download
	cd $(TMPDIR)/ && \
		zip -FSr $(basename $(notdir ${TMPDIR}/noas)).zip \
		$(basename $(notdir ${TMPDIR}/noas))
	@echo "Destination: ${TMPDIR}/noas.zip"

# ------------------------------------------------------------------------------

# run

.PHONY: run_dbimport
run_dbimport: 3rdparty
	R_LIBS_USER=$(BASEDIR)/3rdparty/r_packages \
	LD_LIBRARY_PATH=$(BASEDIR)/3rdparty/postgresql/lib/:$(LD_LIBRARY_PATH) \
	dbimport/main.R

.PHONY: run_webui
run_webui: all
	PORT=$(WEBSERVERPORT) \
	DOCROOT=$(BASEDIR)/webui/www \
	BASEDIR=$(BASEDIR) \
	DBHOST=$(DBHOST) \
	DBPORT=$(DBPORT) \
	DBNAME=$(DBNAME) \
	DBUSER=$(DBUSER) \
	R_LIBS_USER=$(BASEDIR)/3rdparty/r_packages \
	3rdparty/lighttpd/sbin/lighttpd -D -f lighttpd.conf

.PHONY: run_db
run_db: ${DBDATADIR}/postgresql.conf
	3rdparty/postgresql/bin/pg_isready -h localhost -p $(DBPORT) -d $(DBNAME) && $(MAKE) dbstop || true
	3rdparty/postgresql/bin/postgres -D $(DBDATADIR) -h 0.0.0.0 -p $(DBPORT)

# ------------------------------------------------------------------------------

# clean

.PHONY: 
dberase:
	3rdparty/postgresql/bin/pg_ctl -D ${DBDATADIR} stop || true
	$(RM) -r ${DBDATADIR}
	@rm -f /tmp/.s.PGSQL.$(DBPORT).lock

.PHONY: distclean
distclean: clean
	$(MAKE) -C 3rdparty clean

.PHONY: clean
clean: dberase
	$(RM) webui/www/static_info.json
	$(RM) $(websrcs)

# ------------------------------------------------------------------------------

# update

.PHONY: update
update:
	$(RM) webui/www/static_info.json
	git pull
	$(MAKE) all

# ------------------------------------------------------------------------------

# internal

webui/www/%: 3rdparty/%.gz
	zcat < 3rdparty/$*.gz > $@ 

# we depend on git index
webui/www/static_info.json: .git/index
	echo "{" > $@
	echo "\"instance_name\": \"$(INSTANCE_NAME)\"," >> $@
	echo "\"git_hash\": \"$(shell git rev-parse HEAD)\"" >> $@
	echo "}" >> $@

.PHONY: dbstart
dbstart: ${DBDATADIR}/postgresql.conf
	3rdparty/postgresql/bin/pg_isready -h localhost -p $(DBPORT) -d ${DBNAME} || 3rdparty/postgresql/bin/pg_ctl -D ${DBDATADIR} -l ${DBLOGFILE} -w start && echo ok

.PHONY: dbstop
dbstop:
	3rdparty/postgresql/bin/pg_ctl -D ${DBDATADIR} stop
	@rm -f /tmp/.s.PGSQL.$(DBPORT).lock

.PHONY: 3rdparty
3rdparty: $(websrcs)
	$(MAKE) -C 3rdparty

${DBDATADIR}/postgresql.conf: 3rdparty
	bash bin/dbinit.sh
