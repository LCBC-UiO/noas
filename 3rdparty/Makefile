BASEDIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

.PHONY: _all
_add: all

modules := 

include make_postgresql.mk
include make_lighttpd.mk
include make_php.mk

all: $(addsuffix _build, $(modules))
	$(MAKE) -f make_rpacs.mk all

.PHONY: download
download: $(addsuffix _download, $(modules))
	$(MAKE) -f make_rpacs.mk download


.PHONY: clean
clean: $(addsuffix _clean, $(modules))
	$(MAKE) -f make_rpacs.mk clean

