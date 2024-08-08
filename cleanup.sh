#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/common.sh

if [[ $IMAGE == "build-and-lint" ]]
then
    echo "Should cleanup $CUSTOM_ENV_CI_GIT_CLONE_PATH ?"
    exit 0
fi


info "Stopping container $CONTAINER_NAME"

incus stop "$CONTAINER_NAME"
incus delete "$CONTAINER_NAME"
