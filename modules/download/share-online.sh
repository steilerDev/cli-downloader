#!/bin/bash 
source /opt/cli-downloader/modules/download/conf/share-online.conf
# The config needs to have the following lines
#   export SO-USERNANME=""
#   export SO-PASSWORD=""

DOWNLOADER="/opt/cli-downloader/modules/download/bin/share-online.py"

while getopts "hl:" opt; do
    case $opt in
        h)
            echo "http://share-online.biz"
            echo "http://www.share-online.biz"
            ;;
        l)
            sed -i '1s/^/package: share-online\n\n/' $OPTARG
            $DOWNLOADER -s 5 -e $OPTARG
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done
