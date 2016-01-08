#!/bin/sh

# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


set -e

# run as
#    build_haplo_templates.sh ~/haplo
# or whereever the haplo application checkout is located

HAPLO_SOURCE_DIR=$1

if [ X$HAPLO_SOURCE_DIR = X ]
then
  echo "Argument to build_haplo_templates.sh must be the location of the Haplo platform checkout."
  exit 1
fi

JAVA_PACKAGE_ROOT=${HAPLO_SOURCE_DIR}/src/main/java/org/haplo/template/html

if [ ! -f ${JAVA_PACKAGE_ROOT}/Parser.java ]
then
    echo $HAPLO_SOURCE_DIR
    echo "does not look like a checkout of the Haplo platform"
    exit 1
fi

rm -rf tmp-build
mkdir tmp-build

javac -classpath tmp-build -d tmp-build -Xlint:unchecked ${JAVA_PACKAGE_ROOT}/*.java

jar cf haplo-templates.jar -C tmp-build org/haplo/template/html

mv haplo-templates.jar lib/haplo-templates.jar

rm -r tmp-build


