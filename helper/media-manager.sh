#!/bin/bash

DOWNLOAD_DIR="/media/files/Downloads"

OLD_C='\033[1;31m'
NEW_C='\033[1;33m'
NC='\033[0m'


function movie {
    BASE_DIR="/media/files/Movies"
    FORMAT=$1
    shift

    find "$@" -type f | sort | while read FILE; do
        echo -e "Moving file ${NEW_C}${FILE}${NC} ($FORMAT)"

        echo "Please enter the name of the movie"
        read NAME

        echo "Please enter the release year of the movie"
        read YEAR

        NEW_DIR="$BASE_DIR/$FORMAT/$NAME (${YEAR})"
        NEW_PATH="$NEW_DIR/$NAME (${YEAR}).${FILE##*.}"
        echo -e "Moving ${OLD_C}${FILE}${NC} to ${NEW_C}${NEW_PATH}${NC}"

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

    clean "$@"
}

function tv {
    # This script will try to move and sanitize a given file into its correct directory
    # This only works if the target structure is as follows: $DIR/<Show Name>/Season <Season Number>/<Show Name> S__E__.__
    DIR="/media/files/Series"
    SED_DIR="\/media\/files\/Series\/"

    find "$@" -type f | sort | while read FILE; do
        NAME=$(echo $1 | grep -oE "^[A-Za-z]+")
        if [ $(find $DIR -maxdepth 1 | grep $NAME | wc -l) -eq 1 ] ; then
            SHOW_DIR=$(find $DIR -maxdepth 1 | grep $NAME)
            SHOW_NAME=$(echo $SHOW_DIR | sed "s/$SED_DIR//g")
        else
            PS3="Please select the correct show for ${FILE}: "
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

        NEW_PATH="$DIR/$SHOW_NAME/Season $N0_SEASON/$SHOW_NAME S${SEASON}E${EPISODE}.${FILE##*.}"

        if [ ! -d "$DIR" ] ; then
            echo "Cannot find $DIR/"
            exit
        fi

        if [ ! -d "$DIR/$SHOW_NAME" ] ; then
            echo "Cannot find $DIR/$SHOW_NAME/, creating..."
            mkdir -p "$DIR/$SHOW_NAME"
        fi

        if [ ! -d "$DIR/$SHOW_NAME/Season $N0_SEASON" ] ; then
            echo "Cannot find $DIR/$SHOW_NAME/Season $N0_SEASON/, creating..."
            mkdir -p "$DIR/$SHOW_NAME/Season $N0_SEASON"
        fi


        echo -e "Found new path for ${OLD_C}${1}${NC}:"
        echo -e "                   ${NEW_C}${NEW_PATH}${NC}"
        echo

        read -p "Do you want to continue with the move? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mv "$FILE" "$NEW_PATH"
            echo "Success!"
        else
            echo "Abort!"
        fi
        echo
    done
    
    clean "$@"
}

function clean {
    read -p "Do you want to remove the source directory ($@)? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -r "$@"
        echo "Success!"
    else
        echo "Not deleting."
    fi
}

unset options i
while IFS= read -r -d $'\0' f; do
    if [[ $f == $DOWNLOAD_DIR/tv/* ]] ; then
        options[i++]="TV: $(basename $f)"
    elif [[ $f == $DOWNLOAD_DIR/uhd/* ]] ; then
        options[i++]="UHD Movie: $(basename $f)"
    elif [[ $f == $DOWNLOAD_DIR/hd/* ]] ; then
        options[i++]="HD Movie: $(basename $f)"
    fi
done < <(find $DOWNLOAD_DIR -mindepth 2 -maxdepth 2 -type d -print0 )

select opt in "${options[@]}" "Quit"; do
  case $opt in
    TV*)
      tv ${DOWNLOAD_DIR}/tv/$(echo $opt | cut -c 5-)/
      break
      ;;
    HD*)
      movie HD ${DOWNLOAD_DIR}/hd/$(echo $opt | cut -c 11-)/
      ;;
    UHD*)
      movie UHD ${DOWNLOAD_DIR}/uhd/$(echo $opt | cut -c 12-)/
      ;;
    "Quit")
      echo "You chose to stop"
      exit
      ;;
    *)
      echo "This is not a number"
      ;;
  esac
done
