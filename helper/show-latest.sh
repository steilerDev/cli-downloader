#!/bin/bash

# This script will show the latest episode of a given show.
# This only works, if the files are stored as follows: $MEDIA_DIR/<Show Name>/Season <Season Number>/<Show Name> S__E__.__

MEDIA_DIR="/media/files/Series"

SHOW_C='\033[1;36m'
SEASON_C='\033[1;31m'
EPISODE_C='\033[1;33m'
NC='\033[0m'

cd $MEDIA_DIR

read -e -p "Please state the TV Show you want to check: " SHOW

# Input parameter needs to be a Series name (aka a folder in $MEDIA_DIR)
if [ -d "$MEDIA_DIR/$SHOW" ]; then
    LATEST_SEASON=$(ls -Q "$MEDIA_DIR/$SHOW" | xargs -n 1 | tail -n 1 )
    if [ -n "$LATEST_SEASON" ]; then
        if [ -d "$MEDIA_DIR/$SHOW/$LATEST_SEASON" ]; then
            LATEST_EPISODE=$(ls -Q "$MEDIA_DIR/$SHOW/$LATEST_SEASON" | xargs -n 1 | tail -n 1 )
            if [ -n "$LATEST_EPISODE" ]; then
                echo -e "################################################################################"
                echo -e "TV Show: ${SHOW_C}$(echo $SHOW | sed 's/.$//')${NC}"
                echo -e "################################################################################"
                echo -e "Latest Season:  ${SEASON_C}${LATEST_SEASON}${NC}"
                echo -e "Latest Episode: ${EPISODE_C}${LATEST_EPISODE}${NC}"
                echo -e "################################################################################"
            else
                echo "No latest episode in Season $LATEST_SEASON"
            fi
        else
            echo "Could not find $MEDIA_DIR/$1/$LATEST_SEASON"
        fi
    else
        echo "Not latest season!"
    fi
else
    echo "Could not find $MEDIA_DIR/$1"
    exit
fi
