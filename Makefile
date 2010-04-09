all: \
	build/runtime-bare.js \
	build/runtime-safe.js \
	build/compiler.js \
	build/compiler-inlining.js \
	build/repl.js \
	build/examples/naive-repl.html \
	build/examples/repl.html \
	build/examples/debug-repl.html

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

.PHONY: clean
clean:
	bin/clean-build.sh