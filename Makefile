.PHONY: build test check golden install web

build:
	c3c build mdv

test:
	c3c test

check: build
	test/golden.sh

golden: build
	test/golden.sh update

install: build
	install -D -m 755 build/mdv $(HOME)/.local/bin/mdv

web:
	c3c build web
	web/build.sh
