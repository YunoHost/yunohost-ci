#!/usr/bin/env bash

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base.sh # Get variables from base.

set -eo pipefail

# trap any error, and mark it as a system failure.
trap "exit $SYSTEM_FAILURE_EXIT_CODE" ERR

clean_containers()
{
	for image_to_delete in "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION"{,"-tmp"}
	do
		if lxc info $image_to_delete &>/dev/null
		then
			lxc delete $image_to_delete --force
		fi
	done

	for image_to_delete in "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-"{"before-install","before-postinstall","after-postinstall"}
	do
		if lxc image info $image_to_delete &>/dev/null
		then
			lxc image delete $image_to_delete
		fi
	done
}

wait_container()
{
	# Wait for container to start, we are using systemd to check this,
	# for the sake of brevity.
	for i in $(seq 1 10); do
		if lxc exec "$1" -- /bin/bash -c "systemctl isolate multi-user.target" >/dev/null 2>/dev/null; then
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

rebuild_base_container()
{
	clean_containers

	lxc launch images:debian/$DEBIAN_VERSION/$ARCH "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp"
	
	wait_container "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp"

	lxc exec "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp" -- /bin/bash -c "apt-get update"
	lxc exec "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp" -- /bin/bash -c "apt-get install curl -y"
	# Install Git LFS, git comes pre installed with ubuntu image.
	lxc exec "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp" -- /bin/bash -c "curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash"
	lxc exec "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp" -- /bin/bash -c "apt-get install git-lfs -y"
	# Install gitlab-runner binary since we need for cache/artifacts.
	lxc exec "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp" -- /bin/bash -c "curl -s https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash"
	lxc exec "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp" -- /bin/bash -c "apt-get install gitlab-runner -y"
	lxc stop "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp"

	# Create image before install
	lxc publish "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp" --alias "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-before-install"
	lxc start "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp"
	wait_container "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp"

	# Install yunohost
	lxc exec "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp" -- /bin/bash -c "curl https://install.yunohost.org | bash -s -- -a -d $CURRENT_VERSION"
	lxc stop "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp"

	# Create image before postinstall
	lxc publish "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp" --alias "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-before-postinstall"
	lxc start "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp"
	wait_container "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp"

	# Running post Install
	lxc exec "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp" -- /bin/bash -c "yunohost tools postinstall -d domain.tld -p the_password --ignore-dyndns"
	lxc stop "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp"

	# Create image after postinstall
	lxc publish "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp" --alias "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-after-postinstall"

	lxc delete "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-tmp"
}

update_image() {
	image_to_update=$1

	# Start and run upgrade
	lxc launch "$image_to_update" "$image_to_update-tmp"
	
	wait_container "$image_to_update-tmp"

	lxc exec "$image_to_update-tmp" -- /bin/bash -c "apt-get update"
	lxc exec "$image_to_update-tmp" -- /bin/bash -c "apt-get upgrade -y"
	lxc stop "$image_to_update-tmp"

	# Remove old image
	lxc image delete "$image_to_update"

	# Add new image updated
	lxc publish "$image_to_update-tmp" --alias "$image_to_update"

	lxc delete "$image_to_update-tmp"
}

start_container () {
	set -x

	if lxc info "$CONTAINER_ID" >/dev/null 2>/dev/null ; then
		echo 'Found old container, deleting'
		lxc delete -f "$CONTAINER_ID"
	fi

	if ! lxc image info "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-$SNAPSHOT_NAME" &>/dev/null
	then
		rebuild_base_container
	fi

	update_image "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-$SNAPSHOT_NAME"

	lxc launch "yunohost-$DEBIAN_VERSION-$CURRENT_VERSION-$SNAPSHOT_NAME" "$CONTAINER_ID" 2>/dev/null

	mkdir -p ${currentDir}/cache
	chmod 777 ${currentDir}/cache
	lxc config device add "$CONTAINER_ID" cache-folder disk path=/cache source="${currentDir}/cache"

	set +x

	wait_container $CONTAINER_ID
}

echo "Running in $CONTAINER_ID"

start_container
