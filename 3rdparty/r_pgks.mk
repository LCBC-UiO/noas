# sequential building
MAKEFLAGS := -j 1

BASEDIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

.PHONY: _all
_all: all

# packages

# note: the non-Archive urls will break over time. this wil need updates
r_pkg_urls := \
	https://cran.r-project.org/src/contrib/Archive/digest/digest_0.6.25.tar.gz \
	https://cran.r-project.org/src/contrib/Archive/jsonlite/jsonlite_1.7.1.tar.gz \
	https://cran.r-project.org/src/contrib/RPostgreSQL_0.6-2.tar.gz \
	https://cran.r-project.org/src/contrib/DBI_1.1.0.tar.gz

r_pkgs := $(notdir $(r_pkg_urls))

# package dependencies
./r_packages/RPostgreSQL_0.6-2_deps: ./r_packages/DBI_1.1.0
./r_packages/RPostgreSQL_0.6-2: export PATH := $(BASEDIR)/postgresql/bin/:$(PATH)

#-------------------------------------------------------------------------------

# dummy deps
r_pkg_deps := $(addsuffix _deps, $(patsubst %, ./r_packages/%, $(r_pkgs)))
.PHONY: $(r_pkg_deps)
$(r_pkg_deps): 

# download
r_pkgs_dl := $(patsubst %, ./download/%.tar.gz, $(r_pkgs))
$(r_pkgs_dl): ./download/%.tar.gz:
	mkdir -p ./download/
	wget $(filter %$($*).tar.gz, $(r_pkg_urls)) -O $@  # the filter func returns one url

# install
r_pkgs_isnt := $(patsubst %, ./r_packages/%, $(r_pkgs))
.PHONY: $(r_pkgs_isnt)
$(r_pkgs_isnt): ./r_packages/%: ./download/%.tar.gz ./r_packages/%_deps
	mkdir -p ./r_packages/
  # get package name (without version string) and test if folder exists
	test -d $(addprefix ./r_packages/, $(firstword $(subst _, , $*))) \
		|| Rscript -e 'options(warn = 2); install.packages("./download/$*.tar.gz", lib="./r_packages/", repos=NULL)'

$(r_pkgs): %: ./r_packages/%

#-------------------------------------------------------------------------------

all: $(r_pkgs)

.PHONY: download
download: $(r_pkgs_dl)

dlclean: 
	$(RM) ./download/*.tar.gz

clean:
	$(RM) -r ./r_packages/*