.PHONY: all
all: lib runtimes compilers repls examples

.PHONY: lib
lib: \
	src/lib/preamble.ss \
	src/lib/r6rs-list.ss \
	src/lib/object.ss \
	src/lib/module.ss \
	src/lib/generic-parser.ss \
	src/lib/simple-markup.ss \
	src/lib/javascript.ss \
	src/lib/primitive-syntax.ss \
	src/lib/macro.ss \
	src/lib/list.js

	cp $^ build/lib/

.PHONY: runtimes
runtimes: \
	build/standalone/runtime-bare.js \
	build/standalone/runtime-safe.js

.PHONY: compilers
compilers: \
	build/standalone/compiler.js \
	build/standalone/compiler-inlining.js

.PHONY: repls
repls: \
	build/standalone/repl.js \
	build/standalone/repl-inlining.js

.PHONY: examples
examples: \
	build/examples/naive-repl.html \
	build/examples/repl.html \
	build/examples/debug-repl.html

.PHONY: tests
tests: \
	build/tests/suite.html

build/standalone/runtime-bare.js: \
	src/runtime/base.js \
	src/runtime/values-bare.js \
	src/runtime/values.js \
	src/runtime/core-bare.js \
	src/runtime/core.js \
	src/runtime/top-bare.js \
	src/runtime/top.js

	cat $^ | bin/compressor.sh >$@

build/standalone/runtime-safe.js: \
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

build/standalone/compiler.js: \
	build/standalone/runtime-safe.js \
	src/compiler/reader.js \
	src/compiler/inspector.js \
	src/compiler/tools.js \
	src/compiler/compiler-code.js \
	src/compiler/compiler.js 

	cat $^ | bin/compressor.sh >$@

build/standalone/compiler-inlining.js: \
	build/standalone/compiler.js \
	src/compiler/compiler-inlines.js 

	cat $^ | bin/compressor.sh >$@

build/standalone/repl-inlining.js: \
	build/standalone/compiler-inlining.js \
	src/compiler/evaluator.js \
	src/compiler/html.js \
	src/examples/start-repl.js

	cat $^ | bin/compressor.sh >$@

build/standalone/repl.js: \
	build/standalone/compiler.js \
	src/compiler/evaluator.js \
	src/compiler/html.js \
	src/examples/start-repl.js

	cat $^ | bin/compressor.sh >$@

build/examples/naive-repl.html : \
	build/standalone/repl.js \
	src/examples/naive-repl.html

	cp $^ build/examples/

build/examples/repl.html : \
	build/standalone/repl.js \
	src/examples/repl.html \
	src/lib/preamble.ss \
	src/lib/r6rs-list.ss \
	src/lib/object.ss \
	src/lib/module.ss \
	src/lib/generic-parser.ss \
	src/lib/simple-markup.ss \
	src/lib/javascript.ss \
	src/lib/primitive-syntax.ss \
	src/lib/macro.ss \
	src/lib/list.js

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
	src/compiler/evaluator.js \
	src/compiler/html.js \
	src/examples/start-repl.js \
	src/examples/debug-repl.html \
	src/lib/preamble.ss \
	src/lib/r6rs-list.ss \
	src/lib/object.ss \
	src/lib/module.ss \
	src/lib/generic-parser.ss \
	src/lib/simple-markup.ss \
	src/lib/javascript.ss \
	src/lib/primitive-syntax.ss \
	src/lib/macro.ss \
	src/lib/list.js

	cp $^ build/examples/

build/tests/suite.html : \
	src/tests/empty.html \
	src/tests/util.js \
	src/tests/platform.js \
	src/tests/loadable.js \
	src/tests/values.js \
	src/tests/language.js \
	src/tests/platform.ss \
	src/tests/core.ss \
	src/tests/lambda.ss \
	src/tests/suite.html

	cp $^ build/tests/

.PHONY: install
install: \
	install-directories \
	install-lib \
	install-standalone \
	install-examples \
	install-tests

.PHONY: install-directories
install-directories:
	mkdir -p $(MOOSKY_INSTALL_TARGET)/examples
	mkdir -p $(MOOSKY_INSTALL_TARGET)/lib
	mkdir -p $(MOOSKY_INSTALL_TARGET)/standalone
	mkdir -p $(MOOSKY_INSTALL_TARGET)/tests


.PHONY: install-lib
install-lib: \
	build/lib/preamble.ss \
	build/lib/r6rs-list.ss \
	build/lib/object.ss \
	build/lib/module.ss \
	src/lib/generic-parser.ss \
	src/lib/simple-markup.ss \
	src/lib/javascript.ss \
	src/lib/primitive-syntax.ss \
	src/lib/macro.ss \
	src/lib/list.js

	cp $^ $(MOOSKY_INSTALL_TARGET)/lib/


.PHONY: install-standalone
install-standalone: \
	build/standalone/runtime-bare.js \
	build/standalone/runtime-safe.js \
	build/standalone/compiler.js \
	build/standalone/compiler-inlining.js \
	build/standalone/repl.js

	cp build/standalone/* $(MOOSKY_INSTALL_TARGET)/standalone/


.PHONY: install-examples
install-examples: \
	build/examples/naive-repl.html \
	build/examples/repl.html \
	build/examples/debug-repl.html 

	cp build/examples/* $(MOOSKY_INSTALL_TARGET)/examples/

.PHONY: install-test-directories
install-test-directories:
	mkdir -p $(MOOSKY_INSTALL_TARGET)/tests/components
	mkdir -p $(MOOSKY_INSTALL_TARGET)/tests/lib
	mkdir -p $(MOOSKY_INSTALL_TARGET)/tests/standalone

.PHONY: install-test-components
install-test-components: \
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
	src/compiler/evaluator.js \
	src/compiler/html.js

	cp $^ $(MOOSKY_INSTALL_TARGET)/tests/components/


.PHONY: install-test-lib
install-test-lib: \
	build/lib/preamble.ss \
	build/lib/module.ss \
	build/lib/r6rs-list.ss \

	cp $^ $(MOOSKY_INSTALL_TARGET)/tests/lib/


.PHONY: install-test-standalone
install-test-standalone: \
	build/standalone/runtime-bare.js \
	build/standalone/runtime-safe.js \
	build/standalone/compiler.js \
	build/standalone/compiler-inlining.js \
	build/standalone/repl.js

	cp $^ $(MOOSKY_INSTALL_TARGET)/tests/standalone/


.PHONY: install-tests
install-tests: install-test-directories \
	install-test-components \
	install-test-lib \
	install-test-standalone \
	build/tests/suite.html

	cp build/tests/*.* $(MOOSKY_INSTALL_TARGET)/tests/



.PHONY: clean
clean: 
	bin/clean-build.sh

.PHONY: update
update: all install

