#!/bin/sh

FILES=$1

sed '/debugger;/ d' | bin/yuic --type js

