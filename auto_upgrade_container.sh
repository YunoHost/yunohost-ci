#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/utils.sh # Get utils functions.

for debian_version in "buster" "bullseye"
do
	for ynh_version in "stable" "testing" "unstable"
	do
		for snapshot in "before-install" "after-install"
		do
			update_image $debian_version $ynh_version $snapshot
		done
	done
done
