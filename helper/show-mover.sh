#!/bin/bash

# This script will try to move and sanitize a given file into its correct directory
# This only works if the target structure is as follows: $DIR/<Show Name>/Season <Season Number>/<Show Name> S__E__.__

DIR="/media/files/Series"
SED_DIR="\/media\/files\/Series\/"
NAME=$(echo $1 | grep -oE "^[A-Za-z]+")

OLD_C='\033[1;31m'
NEW_C='\033[1;33m'
NC='\033[0m'

if [ $(find $DIR -maxdepth 1 | grep $NAME | wc -l) -eq 1 ] ; then
    SHOW_DIR=$(find $DIR -maxdepth 1 | grep $NAME)
    SHOW_NAME=$(echo $SHOW_DIR | sed "s/$SED_DIR//g")
else
    PS3='Please select the correct show: '
    eval "options=($(find $DIR -maxdepth 1 | grep $NAME | sed "s/$SED_DIR//g" | sed 's/.*/"&"/'))"
    select opt in "${options[@]}" ; do
        SHOW_NAME="$opt"
        SHOW_DIR="$DIR/$SHOW_NAME"
        break
    done 
fi
SEASON=$(echo $1 | grep -Eo "S[0-9]+" | cut -c 2-)
EPISODE=$(echo $1 | grep -Eo "E[0-9]+" | cut -c 2-)

N0_SEASON=$(echo $SEASON | sed "s/^0*//g")

NEW_PATH="$DIR/$SHOW_NAME/Season $N0_SEASON/$SHOW_NAME S${SEASON}E${EPISODE}.${1##*.}"

if [ ! -d "$DIR" ] ; then
    echo "Cannot find $DIR/"
    exit
fi

if [ ! -d "$DIR/$SHOW_NAME" ] ; then
    echo "Cannot find $DIR/$SHOW_NAME/"
    exit
fi

if [ ! -d "$DIR/$SHOW_NAME/Season $N0_SEASON" ] ; then
    echo "Cannot find $DIR/$SHOW_NAME/Season $N0_SEASON/"
    exit
fi


echo -e "Found new path for ${OLD_C}${1}${NC}:"
echo -e "                   ${NEW_C}${NEW_PATH}${NC}"
echo

read -p "Do you want to continue with the move? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    mv "$1" "$NEW_PATH"
else
    echo "Abort"
fi

