#!/bin/bash

BASE_DIR="/media/files/Movies"

OLD_C='\033[1;31m'
COLOR='\033[1;33m'
NC='\033[0m'

FILE="$1"

for FILE in "$@"; do
    echo -e "Moving file ${COLOR}${FILE}${NC}"

    PS3="Please select the correct format for ${FILE}: "
    options=("UHD" "HD" "DVD")

    select opt in "${options[@]}" ; do
        FORMAT="$opt"
        break
    done

    echo "Please enter the name of the movie"
    read NAME

    echo "Please enter the release year of the movie"
    read YEAR

    NEW_DIR="$BASE_DIR/$FORMAT/$NAME (${YEAR})"
    NEW_PATH="$NEW_DIR/$NAME (${YEAR}).${FILE##*.}"
    echo -e "Moving ${OLD_C}${FILE}${NC} to ${COLOR}${NEW_PATH}${NC}"

    read -p "Do you want to continue with the move? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ ! -e "$NEW_DIR" ] ; then
            mkdir "$NEW_DIR" 
        fi
        mv "$FILE" "$NEW_PATH"
        echo "Success!"
    else
        echo "Abort!"
    fi
    echo
done
