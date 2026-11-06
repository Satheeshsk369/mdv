.PHONY: build test install

build:
	c3c build mdv

test:
	c3c test

install: build
	mkdir -p $(HOME)/.local/bin
	cp build/mdv $(HOME)/.local/bin/mdv
