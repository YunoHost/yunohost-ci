#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/prints.sh
source $current_dir/variables.sh # Get variables from variables.

info "Deleting container $CONTAINER_ID"

lxc delete -f "$CONTAINER_ID"