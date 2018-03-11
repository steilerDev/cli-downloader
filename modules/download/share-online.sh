#!/bin/bash 
# The config needs to have the following lines
#   export SO_USERNANME=""
#   export SO_PASSWORD=""
if [ -e $INSTALL_DIR/modules/download/conf/share-online.conf ]; then
    source $INSTALL_DIR/modules/download/conf/share-online.conf
else
    echo "Unable to load log module ($INSTALL_DIR/modules/download/conf/share-online.conf)!"
fi

if [ -e $INSTALL_DIR/modules/download/bin/share-online.py ]; then
    DOWNLOADER="$INSTALL_DIR/modules/download/bin/share-online.py"
else
    echo "Unable to find downloader binary ($INSTALL_DIR/modules/download/bin/share-online.py)!"
    exit
fi


while getopts "ehl:" opt; do
    case $opt in
        h)
            echo "http://share-online.biz"
            echo "http://www.share-online.biz"
            ;;
        l)
            sed -i '1s/^/package: share-online\n\n/' $OPTARG
            $DOWNLOADER -s 5 -e $OPTARG
            ;;
        e)
            exit 1
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done
