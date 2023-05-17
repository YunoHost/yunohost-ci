#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/utils.sh # Get utils functions.

for debian_version in "bullseye"
do
	rebuild_base_containers "$PREFIX_IMAGE_NAME-$debian_version" "$debian_version" "stable" "amd64"

	for ynh_version in "testing" "unstable"
	do
		for snapshot in "before-install" "after-install"
		do
			restore_snapshot "$PREFIX_IMAGE_NAME-$debian_version" "stable" "$snapshot"

			if [[ "$ynh_version" == "testing" ]]
			then
				repo_version="testing"
			elif [[ "$DISTRIB" == "unstable" ]]
			then
				repo_version="testing unstable"
			fi

			lxc exec "$PREFIX_IMAGE_NAME-$debian_version" -- /bin/bash -c "for FILE in \`ls /etc/apt/sources.list /etc/apt/sources.list.d/*\`;
	do
		sed -i 's@^deb http://forge.yunohost.org.*@& $repo_version@' \$FILE
	done"

			create_snapshot "$PREFIX_IMAGE_NAME-$debian_version" "$ynh_version" "$snapshot"

			update_container "$PREFIX_IMAGE_NAME-$debian_version" "$debian_version" "$ynh_version" "$snapshot"
		done
	done
done


for debian_version in "bookworm"
do
	rebuild_base_containers "$PREFIX_IMAGE_NAME-$debian_version" "$debian_version" "unstable" "amd64"
done

