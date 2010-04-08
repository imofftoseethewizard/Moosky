all: \
	build/runtime-bare.js \
	build/runtime-safe.js \
	build/compiler.js \
	build/compiler-inlining.js \
	build/repl.js

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
	src/compiler/html.js

	cat $^ | bin/compressor.sh >$@

.PHONY: clean
clean:
	bin/clean-build.sh