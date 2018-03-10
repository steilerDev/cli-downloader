#!/bin/bash 

LINK_FILE=""
DLC_FILE=""

while getopts "l:d:" opt; do
    case $opt in
        l)
            LINK_FILE="$OPTARG"
            ;;
        d)
            DLC_FILE="$OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

if [ ! -e $LINK_FILE ]; then
    echo "Cannot find link file ($LINK_FILE)"
    exit
fi

if [ ! -e $DLC_FILE ]; then
    echo "Cannot find dlc file ($DLC_FILE)"
    exit
fi


BOUNDARY="---------------------------312412633113176"
TEMP_FILE=".dcrypt.$$.tmp"

#
# Creating DLC decrypt payload
#
> $TEMP_FILE
echo "--$BOUNDARY" >> $TEMP_FILE
echo "Content-Disposition: form-data; name=\"dlcfile\"; filename=\"$(basename $DLC_FILE)\"" >> $TEMP_FILE
echo "Content-Type: application/octet-stream" >> $TEMP_FILE
echo >> $TEMP_FILE
cat $DLC_FILE >> $TEMP_FILE
echo >> $TEMP_FILE
echo "--$BOUNDARY--" >> $TEMP_FILE

#
# Decrypting dlc and getting premium link list
#
echo "Decrypting DLC ($(basename $DLC_FILE))..."
curl -s 'http://dcrypt.it/decrypt/upload' \
    -H 'Pragma: no-cache' \
    -H 'Origin: http://dcrypt.it' \
    -H 'Accept-Encoding: gzip, deflate' \
    -H 'Accept-Language: de-DE,de;q=0.8,en-US;q=0.6,en;q=0.4' \
    -H 'Upgrade-Insecure-Requests: 1' \
    -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36' \
    -H "Content-Type: multipart/form-data; boundary=$BOUNDARY" \
    -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' \
    -H 'Cache-Control: no-cache' \
    -H 'Referer: http://dcrypt.it/' \
    -H 'Cookie: __utmt=1; __utma=100840980.2102576475.1520506516.1520506516.1520506516.1; __utmb=100840980.1.10.1520506516; __utmc=100840980; __utmz=100840980.1520506516.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)' \
    -H 'Connection: keep-alive' \
    --data-binary @$TEMP_FILE --compressed | sed '1d;$d' | \
        jq -r -c '.success.links[]' >> $LINK_FILE

rm $TEMP_FILE

echo "Successfully decrypted DLC ($(basename $DLC_FILE))!"
