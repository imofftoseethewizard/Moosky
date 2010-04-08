#!/bin/sh

(cd $MOOSKY_ROOT; \
    bin/cat-compress.sh >build/runtime/safe.js \
	"runtime/base.js \
	 runtime/values-bare.js \
	 runtime/values-safe.js
	 runtime/values.js \
	 runtime/runtime-bare.js \
	 runtime/runtime-safe.js \
	 runtime/runtime.js
	 runtime/runtime-bare-top.js \
	 runtime/runtime-safe-top.js \
	 runtime/top.js")
