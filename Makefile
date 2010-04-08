all: \
	build/runtime/bare.js \
	build/runtime/safe.js

build/runtime/bare.js: \
	src/runtime/base.js \
	src/runtime/values-bare.js \
	src/runtime/values.js \
	src/runtime/runtime-bare.js \
	src/runtime/runtime.js \
	src/runtime/runtime-bare-top.js \
	src/runtime/top.js

	cat $^ | bin/compressor.sh >$@

build/runtime/safe.js: \
	src/runtime/base.js \
	src/runtime/values-bare.js \
	src/runtime/values-safe.js \
	src/runtime/values.js \
	src/runtime/runtime-bare.js \
	src/runtime/runtime-safe.js \
	src/runtime/runtime.js \
	src/runtime/runtime-bare-top.js \
	src/runtime/runtime-safe-top.js \
	src/runtime/top.js

	cat $^ | bin/compressor.sh >$@

.PHONY: clean
clean:
	bin/clean-build.sh