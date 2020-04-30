#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/base.sh # Get variables from base.

clean_containers()
{
    local base_image_to_clean=$1

	for image_to_delete in "$base_image_to_clean"{,"-tmp"}
	do
		if lxc info $image_to_delete &>/dev/null
		then
			lxc delete $image_to_delete --force
		fi
	done

	for image_to_delete in "$base_image_to_clean-"{"before-install","before-postinstall","after-postinstall"}
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

	# Wait for container to access the internet
	for i in $(seq 1 10); do
		if lxc exec "$1" -- /bin/bash -c "ping -q -c 2 security.debian.org" >/dev/null 2>/dev/null; then
			break
		fi

		if [ "$i" == "10" ]; then
			echo 'Waited for 10 seconds to access the internet, restarting..'
			lxc stop "$1"
			lxc start "$1"

			wait_container "$1"
		fi

		sleep 1s
	done
}

rotate_image()
{
	local instance_to_publish=$1
	local alias_image=$2

	# Save the finger print to delete the old image later 
    local finger_print_to_delete=$(lxc image info "$alias_image" | grep Fingerprint | awk '{print $2}')
	local should_restart=0

	# If the container is running, stop it
	if [ $(lxc info $instance_to_publish | grep Status | awk '{print $2}') = "Running" ]
	then
		should_restart=1
		lxc stop "$instance_to_publish"
	fi

	# Create image before install
	lxc publish "$instance_to_publish" --alias "$alias_image"
	# Remove old image
	lxc image delete "$finger_print_to_delete"
	
	if [ $should_restart = 1 ]
	then
		lxc start "$instance_to_publish"
		wait_container "$instance_to_publish"
	fi
}


rebuild_base_containers()
{
    local debian_version=$1
    local ynh_version=$2
    local arch=$3
    local base_image_to_rebuild="yunohost-$debian_version-$ynh_version"

	lxc launch images:debian/$debian_version/$arch "$base_image_to_rebuild-tmp"
	
	wait_container "$base_image_to_rebuild-tmp"

	if [[ "$debian_version" == "buster" ]]
    then
        lxc config set "$base_image_to_rebuild-tmp" security.nesting true # Need this for buster because it is using apparmor
    fi

	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "apt-get update"
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "apt-get install curl -y"
	# Install Git LFS, git comes pre installed with ubuntu image.
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash"
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "apt-get install git-lfs -y"
	# Install gitlab-runner binary since we need for cache/artifacts.
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "curl -s https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash"
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "apt-get install gitlab-runner -y"

	rotate_image "$base_image_to_rebuild-tmp" "$base_image_to_rebuild-before-install"

    if [[ "$debian_version" == "buster" ]]
    then
        INSTALL_SCRIPT="https://raw.githubusercontent.com/YunoHost/install_script/buster-unstable/install_yunohost"
    else
        INSTALL_SCRIPT="https://install.yunohost.org"
    fi
	# Install yunohost
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "curl $INSTALL_SCRIPT | bash -s -- -a -d $ynh_version"

	rotate_image "$base_image_to_rebuild-tmp" "$base_image_to_rebuild-before-postinstall"

	# Running post Install
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "yunohost tools postinstall -d domain.tld -p the_password --ignore-dyndns"

	rotate_image "$base_image_to_rebuild-tmp" "$base_image_to_rebuild-after-postinstall"

	lxc stop "$base_image_to_rebuild-tmp"

	lxc delete "$base_image_to_rebuild-tmp"
}

update_image() {
	local image_to_update=$1

    if ! lxc image info "$image_to_update" &>/dev/null
    then
        echo "Unable to upgrade image $image_to_update"
        return
    fi

	# Start and run upgrade
	lxc launch "$image_to_update" "$image_to_update-tmp"
	
	wait_container "$image_to_update-tmp"

	lxc exec "$image_to_update-tmp" -- /bin/bash -c "apt-get update"
	lxc exec "$image_to_update-tmp" -- /bin/bash -c "apt-get upgrade -y"

	rotate_image "$image_to_update-tmp" "$image_to_update"

	lxc stop "$image_to_update-tmp"

	lxc delete "$image_to_update-tmp"
}