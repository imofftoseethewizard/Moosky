#!/bin/sh

FILES=$1

sed '/debugger;/ d' | yuic --type js --nomunge

