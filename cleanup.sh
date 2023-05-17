#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/prints.sh
source $current_dir/variables.sh # Get variables from variables.

info "Stopping container $CONTAINER_ID"

lxc stop "$CONTAINER_ID"