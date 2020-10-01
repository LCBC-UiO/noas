BASEDIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

.PHONY: _all
_add: all

modules := 

include make_postgresql.mk
include make_lighttpd.mk
include make_php.mk

all: $(addsuffix _build, $(modules))
	$(MAKE) -f r_pgks.mk all

.PHONY: download
download: $(addsuffix _download, $(modules))
	$(MAKE) -f r_pgks.mk download


.PHONY: clean
clean: $(addsuffix _clean, $(modules))
	$(MAKE) -f r_pgks.mk clean

