#!/bin/sh

# Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
# (c) Haplo Services Ltd 2006 - 2022    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


RHINO_FILENAME=rhino-1.7.7.2.jar
RHINO_URL=https://github.com/mozilla/rhino/releases/download/Rhino1_7_7_2_Release/${RHINO_FILENAME}
RHINO_DIGEST=a7c4a9ba8b6922374580d71060ef71eafa994256

cd lib

# ---------------------------------------------------------------------------

set -e

if ! which curl; then
    echo curl is not available, cannot fetch archives
    exit 1
fi
if ! which openssl; then
    echo openssl is not available, cannot verify archives
    exit 1
fi

get_file() {
    GET_NAME=$1
    GET_URL=$2
    GET_FILE=$3
    GET_DIGEST=$4
    if [ -f $GET_FILE ]; then
        echo "${GET_NAME} already downloaded."
    else
        echo "Downloading ${GET_NAME}..."
        curl -L $GET_URL > _tmp_download
        DOWNLOAD_DIGEST=`openssl sha1 < _tmp_download`
        if [ "$GET_DIGEST" = "$DOWNLOAD_DIGEST" -o "(stdin)= $GET_DIGEST" = "$DOWNLOAD_DIGEST" ]; then
            mv _tmp_download $GET_FILE
        else
            rm _tmp_download
            echo "Digest of ${GET_NAME} download was incorrect, expected ${GET_DIGEST}, got ${DOWNLOAD_DIGEST}"
            exit 1
        fi
    fi
}

# ---------------------------------------------------------------------------

get_file Rhino $RHINO_URL $RHINO_FILENAME $RHINO_DIGEST
mv $RHINO_FILENAME js.jar
