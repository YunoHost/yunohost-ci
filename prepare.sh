#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/prints.sh
source $current_dir/utils.sh # Get utils functions.

set -eo pipefail

# trap any error, and mark it as a system failure.
trap "exit $SYSTEM_FAILURE_EXIT_CODE" ERR

start_container () {
	if ! incus info "$CONTAINER_IMAGE" >/dev/null 2>/dev/null ; then
		warn 'Container not found, copying it from the prebuilt image'
		if ! incus info "$BASE_IMAGE" | grep -w "$CURRENT_VERSION-$SNAPSHOT_NAME" >/dev/null
		then
			error "$BASE_IMAGE not found, please rebuild with rebuild_all.sh"
			# Inform GitLab Runner that this is a system failure, so it
			# should be retried.
			exit $SYSTEM_FAILURE_EXIT_CODE
		fi
		incus copy "$BASE_IMAGE" "$CONTAINER_IMAGE"
	fi
	# Stop the container if it's running
	if [ "$(incus info $CONTAINER_IMAGE | grep Status | awk '{print tolower($2)}')" == "running" ]; then
		incus stop $CONTAINER_IMAGE
	fi

	info "Debian version: $DEBIAN_VERSION, YunoHost version: $CURRENT_VERSION, Image used: $BASE_IMAGE, Snapshot: $SNAPSHOT_NAME"

	restore_snapshot "$CONTAINER_IMAGE" "$CURRENT_VERSION" "$SNAPSHOT_NAME"

	# Unset the mac address to ensure the copy will get a new one and will be able to get new IP
	incus config unset "$CONTAINER_IMAGE" volatile.eth0.hwaddr 2> /dev/null

	incus start $CONTAINER_IMAGE

	wait_container $CONTAINER_IMAGE
}

info "Starting $CONTAINER_IMAGE"

start_container

info "$CONTAINER_IMAGE started properly"
