#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/common.sh

if [[ $IMAGE == "build-and-lint" ]]
then
    incus exec $CONTAINER_NAME -- rm -rf $CUSTOM_ENV_GIT_CLONE_PATH
    incus exec $CONTAINER_NAME -- rm -rf $CUSTOM_ENV_GIT_CLONE_PATH.tmp
    incus exec $CONTAINER_NAME -- rmdir $(dirname $CUSTOM_ENV_GIT_CLONE_PATH) || true
    exit 0
fi

info "Stopping container $CONTAINER_NAME"

incus stop "$CONTAINER_NAME"
incus delete "$CONTAINER_NAME"
