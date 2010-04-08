#!/bin/sh

FILES=$1

(cd $MOOSKY_ROOT/src; cat $FILES) | sed '/debugger;/ d' | yuic --type js --nomunge

