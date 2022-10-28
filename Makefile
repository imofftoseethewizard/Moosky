BIN	= ${MOOSKY}/bin
BUILD	= ${MOOSKY}/build
SRC	= ${MOOSKY}/src

INSTALL ?= ${MOOSKY}/install

.PHONY: all
all: lib runtimes compilers repls examples

.PHONY: lib
lib: \
	${SRC}/lib/preamble.ss \
	${SRC}/lib/r6rs-list.ss \
	${SRC}/lib/object.ss \
	${SRC}/lib/hash.ss \
	${SRC}/lib/digraph.ss \
	${SRC}/lib/class.ss \
	${SRC}/lib/module.ss \
	${SRC}/lib/generic-parser.ss \
	${SRC}/lib/simple-markup.ss \
	${SRC}/lib/javascript.ss \
	${SRC}/lib/primitive-syntax.ss \
	${SRC}/lib/macro.ss

	mkdir -p ${BUILD}/lib
	cp $^ ${BUILD}/lib/

.PHONY: runtimes
runtimes: \
	${BUILD}/standalone/runtime-bare.js \
	${BUILD}/standalone/runtime-safe.js

.PHONY: compilers
compilers: \
	${BUILD}/standalone/compiler.js \
	${BUILD}/standalone/compiler-inlining.js

.PHONY: repls
repls: \
	${BUILD}/standalone/repl.js \
	${BUILD}/standalone/repl-inlining.js

.PHONY: examples
examples: \
	${BUILD}/examples/naive-repl.html \
	${BUILD}/examples/repl.html \
	${BUILD}/examples/debug-repl.html

.PHONY: tests
tests: \
	${BUILD}/tests/suite.html

${BUILD}/modules/runtime-bare.js: \
	${BUILD}/standalone/runtime-bare.js \
	${SRC}/util/commonjs-coda.js

	mkdir -p ${BUILD}/modules
	cat $^ | ${BIN}/compressor.sh >$@

${BUILD}/modules/runtime-safe.js: \
	${BUILD}/standalone/runtime-safe.js \
	${SRC}/util/commonjs-coda.js

	mkdir -p ${BUILD}/modules
	cat $^ | ${BIN}/compressor.sh >$@

${BUILD}/modules/compiler.js: \
	${BUILD}/standalone/compiler.js \
	${SRC}/util/commonjs-coda.js

	mkdir -p ${BUILD}/modules
	cat $^ | ${BIN}/compressor.sh >$@

${BUILD}/modules/compiler-inlining.js: \
	${BUILD}/standalone/compiler-inlining.js \
	${SRC}/util/commonjs-coda.js

	mkdir -p ${BUILD}/modules
	cat $^ | ${BIN}/compressor.sh >$@

${BUILD}/standalone/runtime-bare.js: \
	${SRC}/runtime/base.js \
	${SRC}/runtime/values-bare.js \
	${SRC}/runtime/values.js \
	${SRC}/runtime/core-bare.js \
	${SRC}/runtime/core.js \
	${SRC}/runtime/top-bare.js \
	${SRC}/runtime/top.js

	mkdir -p ${BUILD}/standalone
	cat $^ | ${BIN}/compressor.sh >$@

${BUILD}/standalone/runtime-safe.js: \
	${SRC}/runtime/base.js \
	${SRC}/runtime/values-bare.js \
	${SRC}/runtime/values-safe.js \
	${SRC}/runtime/values.js \
	${SRC}/runtime/core-bare.js \
	${SRC}/runtime/core-safe.js \
	${SRC}/runtime/core.js \
	${SRC}/runtime/top-bare.js \
	${SRC}/runtime/top-safe.js \
	${SRC}/runtime/top.js

	mkdir -p ${BUILD}/standalone
	cat $^ | ${BIN}/compressor.sh >$@

${BUILD}/standalone/compiler.js: \
	${BUILD}/standalone/runtime-safe.js \
	${SRC}/compiler/reader.js \
	${SRC}/compiler/inspector.js \
	${SRC}/compiler/tools.js \
	${SRC}/compiler/compiler-code.js \
	${SRC}/compiler/compiler.js

	mkdir -p ${BUILD}/standalone
	cat $^ | ${BIN}/compressor.sh >$@

${BUILD}/standalone/compiler-inlining.js: \
	${BUILD}/standalone/compiler.js \
	${SRC}/compiler/compiler-inlines.js

	mkdir -p ${BUILD}/standalone
	cat $^ | ${BIN}/compressor.sh >$@

${BUILD}/standalone/repl-inlining.js: \
	${BUILD}/standalone/compiler-inlining.js \
	${SRC}/compiler/evaluator.js \
	${SRC}/compiler/html.js \
	${SRC}/examples/start-repl.js

	mkdir -p ${BUILD}/standalone
	cat $^ | ${BIN}/compressor.sh >$@

${BUILD}/standalone/repl.js: \
	${BUILD}/standalone/compiler.js \
	${SRC}/compiler/evaluator.js \
	${SRC}/compiler/html.js \
	${SRC}/examples/start-repl.js

	mkdir -p ${BUILD}/standalone
	cat $^ | ${BIN}/compressor.sh >$@

${BUILD}/examples/naive-repl.html : \
	${BUILD}/standalone/repl.js \
	${SRC}/examples/naive-repl.html

	mkdir -p ${BUILD}/examples
	cp $^ ${BUILD}/examples/

${BUILD}/examples/repl.html : \
	${BUILD}/standalone/repl.js \
	${SRC}/examples/repl.html \
	${SRC}/lib/preamble.ss \
	${SRC}/lib/r6rs-list.ss \
	${SRC}/lib/object.ss \
	${SRC}/lib/hash.ss \
	${SRC}/lib/digraph.ss \
	${SRC}/lib/class.ss \
	${SRC}/lib/module.ss \
	${SRC}/lib/generic-parser.ss \
	${SRC}/lib/simple-markup.ss \
	${SRC}/lib/javascript.ss \
	${SRC}/lib/primitive-syntax.ss \
	${SRC}/lib/macro.ss

	mkdir -p ${BUILD}/examples
	cp $^ ${BUILD}/examples/

${BUILD}/examples/debug-repl.html : \
	${SRC}/runtime/base.js \
	${SRC}/runtime/values-bare.js \
	${SRC}/runtime/values-safe.js \
	${SRC}/runtime/values.js \
	${SRC}/runtime/core-bare.js \
	${SRC}/runtime/core-safe.js \
	${SRC}/runtime/core.js \
	${SRC}/runtime/top-bare.js \
	${SRC}/runtime/top-safe.js \
	${SRC}/runtime/top.js \
	${SRC}/compiler/reader.js \
	${SRC}/compiler/inspector.js \
	${SRC}/compiler/tools.js \
	${SRC}/compiler/compiler-code.js \
	${SRC}/compiler/compiler.js \
	${SRC}/compiler/compiler-inlines.js \
	${SRC}/compiler/evaluator.js \
	${SRC}/compiler/html.js \
	${SRC}/examples/start-repl.js \
	${SRC}/examples/debug-repl.html \
	${SRC}/lib/preamble.ss \
	${SRC}/lib/r6rs-list.ss \
	${SRC}/lib/object.ss \
	${SRC}/lib/hash.ss \
	${SRC}/lib/digraph.ss \
	${SRC}/lib/class.ss \
	${SRC}/lib/module.ss \
	${SRC}/lib/generic-parser.ss \
	${SRC}/lib/simple-markup.ss \
	${SRC}/lib/javascript.ss \
	${SRC}/lib/primitive-syntax.ss \
	${SRC}/lib/macro.ss

	mkdir -p ${BUILD}/examples
	cp $^ ${BUILD}/examples/

${BUILD}/tests/suite.html : \
	${SRC}/tests/empty.html \
	${SRC}/tests/util.js \
	${SRC}/tests/platform.js \
	${SRC}/tests/loadable.js \
	${SRC}/tests/values.js \
	${SRC}/tests/language.js \
	${SRC}/tests/platform.ss \
	${SRC}/tests/core.ss \
	${SRC}/tests/lambda.ss \
	${SRC}/tests/suite.html

	mkdir -p ${BUILD}/tests
	cp $^ ${BUILD}/tests/

.PHONY: install
install: \
        all \
	install-lib \
	install-modules \
	install-standalone \
	install-examples \
	install-tests

.PHONY: install-lib
install-lib: \
	${BUILD}/lib/preamble.ss \
	${BUILD}/lib/r6rs-list.ss \
	${BUILD}/lib/object.ss \
	${BUILD}/lib/hash.ss \
	${BUILD}/lib/digraph.ss \
	${BUILD}/lib/class.ss \
	${BUILD}/lib/module.ss \
	${SRC}/lib/generic-parser.ss \
	${SRC}/lib/simple-markup.ss \
	${SRC}/lib/javascript.ss \
	${SRC}/lib/primitive-syntax.ss \
	${SRC}/lib/macro.ss

	mkdir -p ${INSTALL}/lib
	cp $^ $(INSTALL)/lib/


.PHONY: install-modules
install-modules: \
	${BUILD}/modules/runtime-bare.js \
	${BUILD}/modules/runtime-safe.js \
	${BUILD}/modules/compiler.js \
	${BUILD}/modules/compiler-inlining.js

	mkdir -p ${INSTALL}/modules
	cp ${BUILD}/modules/* $(INSTALL)/modules/

.PHONY: install-standalone
install-standalone: \
	${BUILD}/standalone/runtime-bare.js \
	${BUILD}/standalone/runtime-safe.js \
	${BUILD}/standalone/compiler.js \
	${BUILD}/standalone/compiler-inlining.js \
	${BUILD}/standalone/repl.js

	mkdir -p ${INSTALL}/standalone
	cp ${BUILD}/standalone/* $(INSTALL)/standalone/

.PHONY: install-examples
install-examples: \
	${BUILD}/examples/naive-repl.html \
	${BUILD}/examples/repl.html \
	${BUILD}/examples/debug-repl.html

	mkdir -p ${INSTALL}/examples
	cp ${BUILD}/examples/* $(INSTALL)/examples/

.PHONY: install-test-components
install-test-components: \
	${SRC}/runtime/base.js \
	${SRC}/runtime/values-bare.js \
	${SRC}/runtime/values-safe.js \
	${SRC}/runtime/values.js \
	${SRC}/runtime/core-bare.js \
	${SRC}/runtime/core-safe.js \
	${SRC}/runtime/core.js \
	${SRC}/runtime/top-bare.js \
	${SRC}/runtime/top-safe.js \
	${SRC}/runtime/top.js \
	${SRC}/compiler/reader.js \
	${SRC}/compiler/inspector.js \
	${SRC}/compiler/tools.js \
	${SRC}/compiler/compiler-code.js \
	${SRC}/compiler/compiler.js \
	${SRC}/compiler/compiler-inlines.js \
	${SRC}/compiler/evaluator.js \
	${SRC}/compiler/html.js

	mkdir -p ${INSTALL}/tests/components
	cp $^ $(INSTALL)/tests/components/

.PHONY: install-test-lib
install-test-lib: \
	${BUILD}/lib/preamble.ss \
	${BUILD}/lib/module.ss \
	${BUILD}/lib/r6rs-list.ss \

	mkdir -p ${INSTALL}/tests/lib
	cp $^ $(INSTALL)/tests/lib/

.PHONY: install-test-standalone
install-test-standalone: \
	${BUILD}/standalone/runtime-bare.js \
	${BUILD}/standalone/runtime-safe.js \
	${BUILD}/standalone/compiler.js \
	${BUILD}/standalone/compiler-inlining.js \
	${BUILD}/standalone/repl.js

	mkdir -p ${INSTALL}/tests/standalone
	cp $^ $(INSTALL)/tests/standalone/

.PHONY: install-tests
install-tests: \
	install-test-components \
	install-test-lib \
	install-test-standalone \
	${BUILD}/tests/suite.html

	mkdir -p ${INSTALL}/tests
	cp ${BUILD}/tests/*.* $(INSTALL)/tests/

.PHONY: clean
clean:
	rm -rf ${BUILD}

.PHONY: update
update: all install
