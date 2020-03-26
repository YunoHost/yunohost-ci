#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/base.sh # Get variables from base.
source $current_dir/utils.sh # Get utils functions.

set -eo pipefail

# trap any error, and mark it as a system failure.
trap "exit $SYSTEM_FAILURE_EXIT_CODE" ERR

start_container () {
	set -x

	if lxc info "$CONTAINER_ID" >/dev/null 2>/dev/null ; then
		echo 'Found old container, deleting'
		lxc delete -f "$CONTAINER_ID"
	fi

	if ! lxc image info "$BASE_IMAGE-$SNAPSHOT_NAME" &>/dev/null
	then
		echo "$BASE_IMAGE not found, please rebuild with rebuild_all.sh"
		# Inform GitLab Runner that this is a system failure, so it
		# should be retried.
		exit $SYSTEM_FAILURE_EXIT_CODE
	fi

	lxc launch "$BASE_IMAGE-$SNAPSHOT_NAME" "$CONTAINER_ID" 2>/dev/null

	mkdir -p $current_dir/cache
	chmod 777 $current_dir/cache
	lxc config device add "$CONTAINER_ID" cache-folder disk path=/cache source="$current_dir/cache"

	set +x

	wait_container $CONTAINER_ID
}

echo "Running in $CONTAINER_ID"

start_container
