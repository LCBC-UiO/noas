# sequential building
MAKEFLAGS := -j 1

BASEDIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

.PHONY: _all
_all: all

# packages
r_pkgs := \
	digest_0.6.25 \
	jsonlite_1.7.1 \
	RPostgreSQL_0.6-2 \
	DBI_1.1.0

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
	wget https://cran.r-project.org/src/contrib/$*.tar.gz -O $@

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