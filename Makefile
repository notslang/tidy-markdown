.PHONY: build clean test

lib/%.json: src/%.json
	mkdir -p lib
	cat "$<" | jq -c '.' > "$@"

lib/%.js: src/%.coffee
	mkdir -p lib
	echo "'use_strict'" \
	| cat - "$<" \
	| ./node_modules/.bin/coffee -b -c -s \
	| ./node_modules/.bin/standard-format - > "$@"

build: $(patsubst src/%.coffee, lib/%.js, $(wildcard src/*.coffee)) \
       $(patsubst src/%, lib/%, $(wildcard src/*.json))

clean:
	rm -rf lib

test: build
	./node_modules/.bin/mocha
