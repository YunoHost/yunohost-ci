#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/prints.sh
source $current_dir/variables.sh # Get variables from variables.

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
				error 'Failed to start the container'
				failstart=1

				restart_container "$1"
			fi

			sleep 1s
		done

		# Wait for container to access the internet
		for j in $(seq 1 10); do
			if lxc exec "$1" -- /bin/bash -c "! which wget > /dev/null 2>&1 || wget -q --spider http://github.com"; then
				break
			fi

			if [ "$j" == "10" ]; then
				error 'Failed to access the internet'
				failstart=1
				lxc exec "$1" -- /bin/bash -c "echo 'resolv-file=/etc/resolv.dnsmasq.conf' > /etc/dnsmasq.d/resolvconf"
				lxc exec "$1" -- /bin/bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.dnsmasq.conf"
				lxc exec "$1" -- /bin/bash -c "sed -i 's/#IGNORE/IGNORE/g' /etc/default/dnsmasq"
				lxc exec "$1" -- /bin/bash -c "systemctl restart dnsmasq"
				lxc exec "$1" -- /bin/bash -c "journalctl -u dnsmasq -n 100 --no-pager"

				restart_container "$1"
			fi

			sleep 1s
		done

		# Wait dpkg
		for j in $(seq 1 10); do
			if  ! lxc exec "$1" -- /bin/bash -c "fuser /var/lib/dpkg/lock > /dev/null 2>&1" &&
				! lxc exec "$1" -- /bin/bash -c "fuser /var/lib/dpkg/lock-frontend > /dev/null 2>&1" &&
				! lxc exec "$1" -- /bin/bash -c "fuser /var/cache/apt/archives/lock > /dev/null 2>&1"; then
				break
			fi

			if [ "$j" == "10" ]; then
				error 'Waiting too long for lock release'
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

create_snapshot()
{
	local instance_to_publish=$1
	local ynh_version=$2
	local snapshot=$3

	# Create snapshot
	lxc snapshot "$instance_to_publish" "$ynh_version-$snapshot" --reuse
}

restore_snapshot()
{
	local instance_to_publish=$1
	local ynh_version=$2
	local snapshot=$3

	lxc restore "$instance_to_publish" "$ynh_version-$snapshot"
}

# These lines are used to extract the dependencies/recommendations from the debian/control file.
# /!\ There's a high risk of lamentable failure if we change the format of this file
get_dependencies()
{
		local debian_version=$1
		if [[ "$debian_version" == "bullseye" ]]
		then
				local branch="dev"
		else
				local branch="$debian_version"
		fi

		# To extract the dependencies, we want to retrieve the lines between "^Dependencies:" and the new line that doesn't start with a space (exclusively) . Then, we remove ",", then we remove the version specifiers "(>= X.Y)", then we add simple quotes to packages when there is a pipe (or) 'php-mysql|php-mysqlnd'.
		YUNOHOST_DEPENDENCIES=$(curl https://raw.githubusercontent.com/YunoHost/yunohost/$branch/debian/control 2> /dev/null | sed -n '/^Depends:/,/^\w/{//!p}' | sed -e "s/,//g" -e "s/[(][^)]*[)]//g" -e "s/ | \S\+//g" | grep -v moulinette | grep -v ssowat | tr "\n" " ")
		YUNOHOST_RECOMMENDS=$(curl https://raw.githubusercontent.com/YunoHost/yunohost/$branch/debian/control 2> /dev/null | sed -n '/^Recommends:/,/^\w/{//!p}' | sed -e "s/,//g" -e "s/[(][^)]*[)]//g" -e "s/ | \S\+//g" | tr "\n" " ")
		MOULINETTE_DEPENDENCIES=$(curl https://raw.githubusercontent.com/YunoHost/moulinette/$branch/debian/control 2> /dev/null | sed -n '/^Depends:/,/^\w/{//!p}' | sed -e "s/,//g" -e "s/[(][^)]*[)]//g" -e "s/ | \S\+//g" | tr "\n" " ")
		# Same as above, except that all dependencies are in the same line
		SSOWAT_DEPENDENCIES=$(curl https://raw.githubusercontent.com/YunoHost/ssowat/$branch/debian/control 2> /dev/null | grep '^Depends:' | sed 's/Depends://' | sed -e "s/,//g" -e "s/[(][^)]*[)]//g" -e "s/ | \S\+//g" | tr "\n" " ")
		BUILD_DEPENDENCIES="git-buildpackage postfix python3-setuptools python3-pip devscripts"
		TESTS_DEPENDENCIES="git hub"
		PIP3_PKG='mock pip pyOpenSSL pytest pytest-cov pytest-mock pytest-sugar requests-mock tox ansi2html black jinja2 types-ipaddress types-enum34 types-cryptography types-toml types-requests types-PyYAML types-pyOpenSSL types-mock  "packaging<22"'

		if [[ "$debian_version" == "bookworm" ]]
		then
				# We add php8.2-cli, mariadb-client and mariadb-server to the dependencies for test_app_resources
				TESTS_DEPENDENCIES="$TESTS_DEPENDENCIES php8.2-cli mariadb-client mariadb-server"
				PIP3_PKG="$PIP3_PKG --break-system-packages"
		fi
}

rebuild_base_containers()
{
	local image_to_rebuild=$1
	local debian_version=$2
	local ynh_version=$3
	local arch=$4

	if lxc info "$image_to_rebuild" &>/dev/null
	then
		lxc delete -f "$image_to_rebuild"
	fi

	lxc launch images:debian/$debian_version/$arch "$image_to_rebuild" -c security.nesting=true
	
	wait_container "$image_to_rebuild"

	lxc exec "$image_to_rebuild" -- /bin/bash -c "apt-get update"
	lxc exec "$image_to_rebuild" -- /bin/bash -c "apt-get install --assume-yes wget curl"
	# Install Git LFS, git comes pre installed with ubuntu image.
	# Disable this line because we don't need to add a new repo to have git-lfs
	#lxc exec "$image_to_rebuild" -- /bin/bash -c "curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash"
	lxc exec "$image_to_rebuild" -- /bin/bash -c "apt-get install --assume-yes git-lfs"
	# Install gitlab-runner binary since we need for cache/artifacts.
	if [[ $debian_version == "bullseye" ]]
	then
			lxc exec "$image_to_rebuild" -- /bin/bash -c "wget https://gitlab-runner-downloads.s3.amazonaws.com/latest/deb/gitlab-runner_amd64.deb"
			lxc exec "$image_to_rebuild" -- /bin/bash -c "dpkg -i gitlab-runner_amd64.deb"
	else
			lxc exec "$image_to_rebuild" -- /bin/bash -c "curl -s https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | os=debian dist=$debian_version bash"
			lxc exec "$image_to_rebuild" -- /bin/bash -c "apt-get install --assume-yes gitlab-runner"
	fi

	INSTALL_SCRIPT="https://raw.githubusercontent.com/YunoHost/install_script/main/$debian_version"

	# Download the YunoHost install script
	lxc exec "$image_to_rebuild" -- /bin/bash -c "curl $INSTALL_SCRIPT > install.sh"
	
	# Patch the YunoHost install script
	lxc exec "$image_to_rebuild" -- /bin/bash -c "sed -i -E 's/(step\s+install_yunohost_packages)/#\1/' install.sh"
	lxc exec "$image_to_rebuild" -- /bin/bash -c "sed -i -E 's/(step\s+restart_services)/#\1/' install.sh"

	# Run the YunoHost install script patched
	lxc exec "$image_to_rebuild" -- /bin/bash -c "cat install.sh | bash -s -- -a -d $ynh_version"

	get_dependencies $debian_version

	# Pre install dependencies
	lxc exec "$image_to_rebuild" -- /bin/bash -c "DEBIAN_FRONTEND=noninteractive SUDO_FORCE_REMOVE=yes apt-get --assume-yes install --assume-yes $YUNOHOST_DEPENDENCIES $YUNOHOST_RECOMMENDS $MOULINETTE_DEPENDENCIES $SSOWAT_DEPENDENCIES $BUILD_DEPENDENCIES $TESTS_DEPENDENCIES"
	lxc exec "$image_to_rebuild" -- /bin/bash -c "python3 -m pip install -U $PIP3_PKG"

	# Disable apt-daily
	lxc exec "$image_to_rebuild" -- /bin/bash -c "systemctl -q stop apt-daily.timer"
	lxc exec "$image_to_rebuild" -- /bin/bash -c "systemctl -q stop apt-daily-upgrade.timer"
	lxc exec "$image_to_rebuild" -- /bin/bash -c "systemctl -q stop apt-daily.service"
	lxc exec "$image_to_rebuild" -- /bin/bash -c "systemctl -q stop apt-daily-upgrade.service"
	lxc exec "$image_to_rebuild" -- /bin/bash -c "systemctl -q disable apt-daily.timer"
	lxc exec "$image_to_rebuild" -- /bin/bash -c "systemctl -q disable apt-daily-upgrade.timer"
	lxc exec "$image_to_rebuild" -- /bin/bash -c "systemctl -q disable apt-daily.service"
	lxc exec "$image_to_rebuild" -- /bin/bash -c "systemctl -q disable apt-daily-upgrade.service"

	
	mkdir -p $current_dir/cache
	chmod 777 $current_dir/cache
	lxc config device add "$image_to_rebuild" cache-folder disk path=/cache source="$current_dir/cache"

	create_snapshot "$image_to_rebuild" "$ynh_version" "before-install"

	# Install YunoHost
	lxc exec "$image_to_rebuild" -- /bin/bash -c "curl $INSTALL_SCRIPT | bash -s -- -a -d $ynh_version"
	
	# Run postinstall
	lxc exec "$image_to_rebuild" -- /bin/bash -c "yunohost tools postinstall -d domain.tld -u syssa -F 'Syssa Mine' -p the_password --ignore-dyndns --force-diskspace"

	create_snapshot "$image_to_rebuild" "$ynh_version" "after-install"

	lxc stop "$image_to_rebuild"
}

update_container() {
	local image_to_update=$1
	local debian_version=$2
	local ynh_version=$3
	local snapshot=$4

	if ! lxc info "$image_to_update" &>/dev/null
	then
		error "Unable to upgrade image $image_to_update"
		return
	fi

	# Start and run upgrade
	restore_snapshot "$image_to_update" "$ynh_version" "$snapshot"
	
	lxc start "$image_to_update" 2>&1 || true

	wait_container "$image_to_update"

	lxc exec "$image_to_update" -- /bin/bash -c "apt-get update"
	lxc exec "$image_to_update" -- /bin/bash -c "apt-get upgrade --assume-yes"
	
	get_dependencies $debian_version

	lxc exec "$image_to_update" -- /bin/bash -c "DEBIAN_FRONTEND=noninteractive SUDO_FORCE_REMOVE=yes apt-get --assume-yes -o Dpkg::Options::=\"--force-confold\" install --assume-yes $YUNOHOST_DEPENDENCIES $YUNOHOST_RECOMMENDS $MOULINETTE_DEPENDENCIES $SSOWAT_DEPENDENCIES $BUILD_DEPENDENCIES $TESTS_DEPENDENCIES"
	lxc exec "$image_to_update" -- /bin/bash -c "python3 -m pip install -U $PIP3_PKG"

	create_snapshot "$image_to_update" "$ynh_version" "$snapshot"

	lxc stop "$image_to_update"
}
