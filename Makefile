.PHONY: build clean test
SHELL=/bin/bash

lib/%.json: src/%.json
	mkdir -p lib
	cat "$<" | jq -c '.' > "$@"

lib/%.js: src/%.coffee
	mkdir -p lib
	# ignore cases where standard returns a non-zero exit code
	echo "'use_strict'" \
	| cat - "$<" \
	| npx coffee -b -c -s > "$@"

build: $(patsubst src/%.coffee, lib/%.js, $(wildcard src/*.coffee)) \
       $(patsubst src/%, lib/%, $(wildcard src/*.json))

clean:
	rm -rf lib

test: build
	./node_modules/.bin/mocha
