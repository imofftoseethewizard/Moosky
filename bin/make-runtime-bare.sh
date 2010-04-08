#!/bin/sh

(cd $MOOSKY_ROOT; \
    bin/cat-compress.sh >build/runtime/bare.js \
	"runtime/base.js \
	 runtime/values-bare.js \
	 runtime/values.js \
	 runtime/runtime-bare.js \
	 runtime/runtime.js
	 runtime/runtime-bare-top.js \
	 runtime/top.js")

