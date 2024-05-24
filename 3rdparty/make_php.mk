modules := $(modules) \
	php

LIBVER_php := 7.4.6

.PHONY: php_download
php_download: download/php-${LIBVER_php}.tar.gz

.PHONY: php_build
php_build: php/bin/php-cgi php/lib/php/extensions/no-debug-non-zts-20190902/xdebug.so

.PHONY: php_clean
php_clean:
	$(RM) -r php
	$(RM) -r php_build

.PHONY: php_dlclean
php_dlclean:
	$(RM) download/php-${LIBVER_php}.tar.gz

download/php-${LIBVER_php}.tar.gz:
	mkdir -p download/
	cd download && wget https://www.php.net/distributions/php-${LIBVER_php}.tar.gz

php/bin/php-cgi: download/php-${LIBVER_php}.tar.gz | postgresql_build
	mkdir -p php_build \
		&& cd php_build \
		&& tar xf ../download/php-${LIBVER_php}.tar.gz \
		&& cd php-$(LIBVER_php) \
		&& ./configure --prefix=$(BASEDIR)/php  --without-iconv --without-libxml --without-sqlite3 --disable-dom --without-pdo-sqlite --disable-simplexml --disable-xml --disable-xmlreader --disable-xmlwriter --with-pgsql=$(BASEDIR)/postgresql --with-pdo-pgsql=$(BASEDIR)/postgresql
	$(MAKE) -C php_build/php-$(LIBVER_php)
	$(MAKE) -C php_build/php-$(LIBVER_php) install
	$(RM) -r php_build

# Change xdebug version if updating php version (https://xdebug.org/wizard)
download/xdebug-3.1.6.tgz:
	mkdir -p download/
	cd download && wget https://xdebug.org/files/xdebug-3.1.6.tgz

php/lib/php/extensions/no-debug-non-zts-20190902/xdebug.so: php/bin/php-cgi download/xdebug-3.1.6.tgz
	mkdir -p $(BASEDIR)/php_xdebug_build \
		&& cd $(BASEDIR)/php_xdebug_build \
		&& tar xf $(BASEDIR)/download/xdebug-3.1.6.tgz \
		&& cd $(BASEDIR)/php_xdebug_build/xdebug-3.1.6 \
		&& $(BASEDIR)/php/bin/phpize \
		&& ./configure --with-php-config=$(BASEDIR)/php/bin/php-config
	$(MAKE) -C $(BASEDIR)/php_xdebug_build/xdebug-3.1.6
	cp $(BASEDIR)/php_xdebug_build/xdebug-3.1.6/modules/xdebug.so $(BASEDIR)/php/lib/php/extensions/no-debug-non-zts-20190902/
	$(RM) -r $(BASEDIR)/php_xdebug_build