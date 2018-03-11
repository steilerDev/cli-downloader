#!/bin/bash 

# Color variables
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[1;31m'
NC='\033[0m'

export LOG_FILE="/tmp/log"

log_start () {
    echo -e "${CYAN}$@${NC}"
    debug $@
}

log_finish () {
    echo -e "${GREEN}$@${NC}"
    debug $@
}

log_error () {
    echo -e "${RED}$@${NC}"
    debug $@
}

log () {
    echo $@ | tee -a $LOG_FILE
}

debug () {
    echo $@ >> $LOG_FILE
}
