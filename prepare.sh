#!/usr/bin/env bash

# /opt/lxd-executor/prepare.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base.sh # Get variables from base.

set -eo pipefail

# trap any error, and mark it as a system failure.
trap "exit $SYSTEM_FAILURE_EXIT_CODE" ERR

rebuild_base_container()
{
	lxc info "yunohost-$DEBIAN_VERSION" >/dev/null && lxc delete "yunohost-$DEBIAN_VERSION" --force
	lxc launch images:debian/$DEBIAN_VERSION/amd64 "yunohost-$DEBIAN_VERSION-tmp"
	lxc exec "yunohost-$DEBIAN_VERSION-tmp" -- sh -c "apt-get install curl -y"
	# Install Git LFS, git comes pre installed with ubuntu image.
    lxc exec "yunohost-$DEBIAN_VERSION-tmp" -- sh -c "curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash"
    lxc exec "yunohost-$DEBIAN_VERSION-tmp" -- sh -c "apt-get install git-lfs -y"
	# Install gitlab-runner binary since we need for cache/artifacts.
	lxc exec "yunohost-$DEBIAN_VERSION-tmp" -- sh -c "curl -s https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash"
	lxc stop "yunohost-$DEBIAN_VERSION-tmp"

	# Create image before install
	lxc publish "yunohost-$DEBIAN_VERSION-tmp" --alias "yunohost-$DEBIAN_VERSION-before-install"
	lxc start "yunohost-$DEBIAN_VERSION-tmp"

	# Install yunohost
	lxc exec "yunohost-$DEBIAN_VERSION-tmp" -- sh -c "curl https://install.yunohost.org | bash -s -- -a -d unstable"
	lxc stop "yunohost-$DEBIAN_VERSION-tmp"

	# Create image before postinstall
	lxc publish "yunohost-$DEBIAN_VERSION-tmp" --alias "yunohost-$DEBIAN_VERSION-before-postinstall"
	lxc start "yunohost-$DEBIAN_VERSION-tmp"

	# Running post Install
	lxc exec "yunohost-$DEBIAN_VERSION-tmp" -- sh -c "yunohost tools postinstall -d domain.tld -p the_password --ignore-dyndns"
	lxc stop "yunohost-$DEBIAN_VERSION-tmp"

	# Create image after postinstall
	lxc publish "yunohost-$DEBIAN_VERSION-tmp" --alias "yunohost-$DEBIAN_VERSION-after-postinstall"

	lxc delete "yunohost-$DEBIAN_VERSION-tmp"
}

start_container () {
	set -x

    if lxc info "$CONTAINER_ID" >/dev/null 2>/dev/null ; then
        echo 'Found old container, deleting'
        lxc delete -f "$CONTAINER_ID"
    fi

	if ! lxc image info "yunohost-$DEBIAN_VERSION-$SNAPSHOT_NAME" &>/dev/null
	then
		rebuild_base_container
	fi
	
	lxc launch "yunohost-$DEBIAN_VERSION-$SNAPSHOT_NAME" "$CONTAINER_ID" 2>/dev/null
	
	set +x

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
