.PHONY: build test check golden install

build:
	c3c build mdv

test:
	c3c test

check: build
	test/golden.sh

golden: build
	test/golden.sh update

install: build
	mkdir -p $(HOME)/.local/bin
	cp build/mdv $(HOME)/.local/bin/mdv
