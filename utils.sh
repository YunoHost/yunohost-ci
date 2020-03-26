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
}

rebuild_base_containers()
{
    local debian_version=$1
    local ynh_version=$2
    local arch=$3
    local base_image_to_rebuild="yunohost-$debian_version-$ynh_version"
    
	clean_containers $base_image_to_rebuild

	lxc launch images:debian/$debian_version/$arch "$base_image_to_rebuild-tmp"
	
	wait_container "$base_image_to_rebuild-tmp"

	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "apt-get update"
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "apt-get install curl -y"
	# Install Git LFS, git comes pre installed with ubuntu image.
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash"
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "apt-get install git-lfs -y"
	# Install gitlab-runner binary since we need for cache/artifacts.
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "curl -s https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash"
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "apt-get install gitlab-runner -y"
	lxc stop "$base_image_to_rebuild-tmp"

	# Create image before install
	lxc publish "$base_image_to_rebuild-tmp" --alias "$base_image_to_rebuild-before-install"
	lxc start "$base_image_to_rebuild-tmp"

	wait_container "$base_image_to_rebuild-tmp"

	# Install yunohost
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "curl https://install.yunohost.org | bash -s -- -a -d $ynh_version"
	lxc stop "$base_image_to_rebuild-tmp"

	# Create image before postinstall
	lxc publish "$base_image_to_rebuild-tmp" --alias "$base_image_to_rebuild-before-postinstall"
	lxc start "$base_image_to_rebuild-tmp"

	wait_container "$base_image_to_rebuild-tmp"

	# Running post Install
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "yunohost tools postinstall -d domain.tld -p the_password --ignore-dyndns"
	lxc stop "$base_image_to_rebuild-tmp"

	# Create image after postinstall
	lxc publish "$base_image_to_rebuild-tmp" --alias "$base_image_to_rebuild-after-postinstall"

	lxc delete "$base_image_to_rebuild-tmp"
}

update_image() {
	local image_to_update=$1

    if ! lxc image info "$image_to_update" &>/dev/null
    then
        echo "Unable to upgrade image $image_to_update"
        return
    fi

    local finger_print_to_delete=$(lxc image info "$image_to_update" | grep Fingerprint | cut -d' ' -f2)

	# Start and run upgrade
	lxc launch "$image_to_update" "$image_to_update-tmp"
	
	wait_container "$image_to_update-tmp"

	lxc exec "$image_to_update-tmp" -- /bin/bash -c "apt-get update"
	lxc exec "$image_to_update-tmp" -- /bin/bash -c "apt-get upgrade -y"
	lxc stop "$image_to_update-tmp"

	# Add new image updated
	lxc publish "$image_to_update-tmp" --alias "$image_to_update"

	# Remove old image
	lxc image delete "$finger_print_to_delete"

	lxc delete "$image_to_update-tmp"
}