#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/utils.sh # Get utils functions.

for debian_version in "bullseye"
do
	for ynh_version in "stable" "testing" "unstable"
	do
		for snapshot in "before-install" "after-install"
		do
			info "Updating container $PREFIX_IMAGE_NAME-$debian_version $ynh_version $snapshot"
			update_container "$PREFIX_IMAGE_NAME-$debian_version" "$debian_version" "$ynh_version" "$snapshot"
		done
	done
	containers_to_remove=$(incus list $PREFIX_IMAGE_NAME-$debian_version-r -c n -f csv)
	if [ -n "$containers_to_remove" ]
	then
		# Remove old runner containers
		incus delete -f $(echo $containers_to_remove)
	fi
done

for debian_version in "bookworm"
do
	for ynh_version in "unstable"
	do
		for snapshot in "before-install" "after-install"
		do
			info "Updating container $PREFIX_IMAGE_NAME-$debian_version $ynh_version $snapshot"
			update_container "$PREFIX_IMAGE_NAME-$debian_version" "$debian_version" "$ynh_version" "$snapshot"
		done
	done
	containers_to_remove=$(incus list $PREFIX_IMAGE_NAME-$debian_version-r -c n -f csv)
	if [ -n "$containers_to_remove" ]
	then
		# Remove old runner containers
		incus delete -f $(echo $containers_to_remove)
	fi
done
