.PHONY: all
all: runtimes compilers repls examples

.PHONY: runtimes
runtimes: \
	build/runtime-bare.js \
	build/runtime-safe.js

.PHONY: compilers
compilers: \
	build/compiler.js \
	build/compiler-inlining.js

.PHONY: repls
repls: \
	build/repl.js

.PHONY: examples
examples: \
	build/examples/naive-repl.html \
	build/examples/repl.html \
	build/examples/debug-repl.html

.PHONY: tests
tests: \
	build/tests/loadable.html \
	build/tests/values-test.html

build/runtime-bare.js: \
	src/runtime/base.js \
	src/runtime/values-bare.js \
	src/runtime/values.js \
	src/runtime/core-bare.js \
	src/runtime/core.js \
	src/runtime/top-bare.js \
	src/runtime/top.js

	cat $^ | bin/compressor.sh >$@

build/runtime-safe.js: \
	src/runtime/base.js \
	src/runtime/values-bare.js \
	src/runtime/values-safe.js \
	src/runtime/values.js \
	src/runtime/core-bare.js \
	src/runtime/core-safe.js \
	src/runtime/core.js \
	src/runtime/top-bare.js \
	src/runtime/top-safe.js \
	src/runtime/top.js

	cat $^ | bin/compressor.sh >$@

build/compiler.js: \
	build/runtime-safe.js \
	src/compiler/reader.js \
	src/compiler/inspector.js \
	src/compiler/tools.js \
	src/compiler/compiler-code.js \
	src/compiler/compiler.js 

	cat $^ | bin/compressor.sh >$@

build/compiler-inlining.js: \
	build/compiler.js \
	src/compiler/compiler-inlines.js 

	cat $^ | bin/compressor.sh >$@

build/repl.js: \
	build/compiler-inlining.js \
	src/compiler/html.js \
	src/examples/start-repl.js

	cat $^ | bin/compressor.sh >$@

build/examples/naive-repl.html : \
	build/repl.js \
	src/examples/naive-repl.html

	cp $^ build/examples/

build/examples/repl.html : \
	build/repl.js \
	src/examples/repl.html \
	src/scheme/preamble.ss \
	src/scheme/r6rs-list.ss

	cp $^ build/examples/

build/examples/debug-repl.html : \
	src/runtime/base.js \
	src/runtime/values-bare.js \
	src/runtime/values-safe.js \
	src/runtime/values.js \
	src/runtime/core-bare.js \
	src/runtime/core-safe.js \
	src/runtime/core.js \
	src/runtime/top-bare.js \
	src/runtime/top-safe.js \
	src/runtime/top.js \
	src/compiler/reader.js \
	src/compiler/inspector.js \
	src/compiler/tools.js \
	src/compiler/compiler-code.js \
	src/compiler/compiler.js \
	src/compiler/compiler-inlines.js \
	src/compiler/html.js \
	src/examples/start-repl.js \
	src/examples/debug-repl.html \
	src/scheme/preamble.ss \
	src/scheme/r6rs-list.ss 

	cp $^ build/examples/

build/tests/loadable.html: \
	src/runtime/base.js \
	src/runtime/values-bare.js \
	src/runtime/values-safe.js \
	src/runtime/values.js \
	src/runtime/core-bare.js \
	src/runtime/core-safe.js \
	src/runtime/core.js \
	src/runtime/top-bare.js \
	src/runtime/top-safe.js \
	src/runtime/top.js \
	src/compiler/reader.js \
	src/compiler/inspector.js \
	src/compiler/tools.js \
	src/compiler/compiler-code.js \
	src/compiler/compiler.js \
	src/compiler/compiler-inlines.js \
	src/compiler/html.js \
	src/tests/start-tests.js \
	src/tests/loadable.js \
	src/tests/loadable.html

	cp $^ build/tests/

build/tests/values-test.html: \
	src/runtime/base.js \
	src/runtime/values-bare.js \
	src/runtime/values.js \
	src/tests/start-tests.js \
	src/tests/values-test.js \
	src/tests/values-test.html

	cp $^ build/tests/

.PHONY: install
install: install-examples install-tests

.PHONY: install-examples
install-examples: \
	build/examples/naive-repl.html \
	build/examples/repl.html \
	build/examples/debug-repl.html 

	cp build/examples/* $(MOOSKY_INSTALL_TARGET)/examples/



.PHONY: install-tests
install-tests: \
	build/tests/loadable.html \
	build/tests/values-test.html

	cp build/tests/* $(MOOSKY_INSTALL_TARGET)/tests/



.PHONY: clean
clean:
	bin/clean-build.sh

.PHONY: update
update: all install

