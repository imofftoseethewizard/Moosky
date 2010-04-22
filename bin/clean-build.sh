#!/bin/sh

BUILD=$MOOSKY_ROOT/build

rm -rf $BUILD
mkdir $BUILD
cd $BUILD
mkdir examples lib standalone tests
(cd tests ; mkdir components lib standalone)
