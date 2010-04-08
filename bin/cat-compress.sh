#!/bin/sh

FILES=$1

cat $FILES | sed '/debugger;/ d' | yuic --type js --nomunge

