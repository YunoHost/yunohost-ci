#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/prints.sh
source $current_dir/utils.sh # Get utils functions.

set -eo pipefail

# trap any error, and mark it as a system failure.
trap "exit $SYSTEM_FAILURE_EXIT_CODE" ERR

start_container () {
	if lxc info "$CONTAINER_ID" >/dev/null 2>/dev/null ; then
		warn 'Found old container, deleting'
		lxc delete -f "$CONTAINER_ID"
	fi

	if ! lxc image info "$BASE_IMAGE-$SNAPSHOT_NAME" &>/dev/null
	then
		error "$BASE_IMAGE not found, please rebuild with rebuild_all.sh"
		# Inform GitLab Runner that this is a system failure, so it
		# should be retried.
		exit $SYSTEM_FAILURE_EXIT_CODE
	fi

	info "Debian version: $DEBIAN_VERSION, YunoHost version: $CURRENT_VERSION, Image used: $BASE_IMAGE-$SNAPSHOT_NAME"

	lxc launch "$BASE_IMAGE-$SNAPSHOT_NAME" "$CONTAINER_ID" -c security.nesting=true 2>/dev/null

	mkdir -p $current_dir/cache
	chmod 777 $current_dir/cache
	lxc config device add "$CONTAINER_ID" cache-folder disk path=/cache source="$current_dir/cache"

	wait_container $CONTAINER_ID
}

info "Starting $CONTAINER_ID"

start_container

info "$CONTAINER_ID started properly"
