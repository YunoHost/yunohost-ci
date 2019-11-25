#!/usr/bin/env bash

# /opt/lxd-executor/prepare.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base.sh # Get variables from base.

set -eo pipefail

# trap any error, and mark it as a system failure.
trap "exit $SYSTEM_FAILURE_EXIT_CODE" ERR

rebuild_base_container()
{
	set -x
	lxc info $CONTAINER_ID-rebuild >/dev/null && sudo lxc delete $CONTAINER_ID-rebuild --force
	lxc launch images:debian/stretch/amd64 $CONTAINER_ID-rebuild
	lxc config set $CONTAINER_ID-rebuild security.privileged true
	lxc restart $CONTAINER_ID-rebuild
	lxc exec $CONTAINER_ID-rebuild -- apt install curl -y
	# Install gitlab-runner binary since we need for cache/artifacts.
	lxc exec $CONTAINER_ID-rebuild -- /bin/bash -c "curl -s https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash"
	# Install yunohost
	lxc exec $CONTAINER_ID-rebuild -- /bin/bash -c "curl https://install.yunohost.org | bash -s -- -a -d unstable"
	lxc stop $CONTAINER_ID-rebuild
	lxc publish $CONTAINER_ID-rebuild --alias $CONTAINER_ID-base
	set +x
}

start_container () {
	if ! lxc image info "$CONTAINER_ID-base" &>/dev/null
	then
		rebuild_base_container
	fi
	if ! lxc info $CONTAINER_ID | grep -q "before-postinstall"
	then
		lxc launch "$CONTAINER_ID-base" "$CONTAINER_ID"
		lxc config set "$CONTAINER_ID" security.privileged true
		lxc snapshot "$CONTAINER_ID" "before-postinstall"
	fi
	if ! lxc info $CONTAINER_ID | grep -q "after-postinstall"
	then
		lxc exec "$CONTAINER_ID" -- sh -c "yunohost tools postinstall -d domain.tld -p the_password --ignore-dyndns"
		lxc snapshot "$CONTAINER_ID" "after-postinstall"
	fi

	lxc restore "$CONTAINER_ID" "$SNAPSHOT_NAME"
	lxc start "$CONTAINER_ID" 2>/dev/null || true

	# Wait for container to start, we are using systemd to check this,
	# for the sake of brevity.
	for i in $(seq 1 10); do
		if lxc exec "$CONTAINER_ID" -- sh -c "systemctl isolate multi-user.target" >/dev/null 2>/dev/null; then
			break
		fi

		if [ "$i" == "10" ]; then
			echo 'Waited for 10 seconds to start container, exiting..'
			# Inform GitLab Runner that this is a system failure, so it
			# should be retried.
			exit "$SYSTEM_FAILURE_EXIT_CODE"
		fi

		sleep 1s
	done
}

echo "Running in $CONTAINER_ID"

start_container
