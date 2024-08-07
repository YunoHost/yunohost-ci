#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/common.sh

info "Stopping container $CONTAINER_NAME"

incus stop "$CONTAINER_NAME"
incus delete "$CONTAINER_NAME"
