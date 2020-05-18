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

	if lxc image info $base_image_to_clean &>/dev/null
	then
		lxc image delete $base_image_to_clean
	fi
}

wait_container()
{
	restart_container()
	{
		lxc stop "$1"
		lxc start "$1"
	}

	# Try to start the container 3 times.
	local max_try=3
	local i=0
	while [ $i -lt $max_try ]
	do
		i=$(( i +1 ))
		local failstart=0

		# Wait for container to start, we are using systemd to check this,
		# for the sake of brevity.
		for j in $(seq 1 10); do
			if lxc exec "$1" -- /bin/bash -c "systemctl isolate multi-user.target" >/dev/null 2>/dev/null; then
				break
			fi

			if [ "$j" == "10" ]; then
				echo 'Waited for 10 seconds to start container'
				failstart=1

				restart_container "$1"
			fi

			sleep 1s
		done

		# Wait for container to access the internet
		for j in $(seq 1 10); do
			if lxc exec "$1" -- /bin/bash -c "getent hosts debian.org" >/dev/null 2>/dev/null; then
				break
			fi

			if [ "$j" == "10" ]; then
				echo 'Waited for 10 seconds to access the internet'
				failstart=1

				restart_container "$1"
			fi

			sleep 1s
		done

		# Has started and has access to the internet
		if [ $failstart -eq 0 ]
		then
			break
		fi

		# Fail if the container failed to start
		if [ $i -eq $max_try ] && [ $failstart -eq 1 ]
		then
			# Inform GitLab Runner that this is a system failure, so it
			# should be retried.
			exit "$SYSTEM_FAILURE_EXIT_CODE"
		fi
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
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "apt-get install --assume-yes wget curl"
	# Install Git LFS, git comes pre installed with ubuntu image.
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash"
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "apt-get install --assume-yes git-lfs"
	# Install gitlab-runner binary since we need for cache/artifacts.
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "curl -s https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash"
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "apt-get install --assume-yes gitlab-runner"

	# Add yunohost repo
	local CUSTOMDEB="deb http://forge.yunohost.org/debian/ stretch stable"
	if [[ "$ynh_version" == "stable" ]] ; then
        CUSTOMDEB="$CUSTOMDEB"
    elif [[ "$ynh_version" == "testing" ]] ; then
        CUSTOMDEB="$CUSTOMDEB testing"
    elif [[ "$ynh_version" == "unstable" ]] ; then
        CUSTOMDEB="$CUSTOMDEB testing unstable"
    fi

	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "echo \"$CUSTOMDEB\" > /etc/apt/sources.list.d/yunohost.list"
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "wget -O- https://forge.yunohost.org/yunohost.asc -q | apt-key add -qq - >/dev/null 2>&1"
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "apt-get update"

	# Patch install dependencies
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "touch /var/log/auth.log"
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "
if ! id avahi > /dev/null 2>&1; then
	avahi_id=$((500 + RANDOM % 500))
	while cut -d ':' -f 3 /etc/passwd | grep -q \$avahi_id
	do
		avahi_id=$((500 + RANDOM % 500))
	done
	adduser --disabled-password  --quiet --system --home /var/run/avahi-daemon --no-create-home --gecos \"Avahi mDNS daemon\" --group avahi --uid \$avahi_id
fi"

	# Pre install dependencies
	lxc exec "$base_image_to_rebuild-tmp" -- /bin/bash -c "apt-get install --assume-yes $YNH_DEPENDENCIES $BUILD_DEPENDENCIES"

	rotate_image "$base_image_to_rebuild-tmp" "$base_image_to_rebuild"

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
