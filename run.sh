#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/base.sh # Get variables from base.

case ${2} in
	prepare_script)
		;;
	get_sources)
		;;
	restore_cache)
		;;
	download_artifacts)
		;;
	build_script)
		case $PROJECT_NAME in
			yunohost)
				echo "Running migrations yunohost"

				# Run migrations
				lxc exec "$CONTAINER_ID" -- sh -c "yunohost tools migrations migrate"
			;;
		esac
		;;
	after_script)
		;;
	archive_cache)
		;;
	upload_artifact_on_success)
		;;
	upload_artifact_on_failure)
		;;
esac


lxc exec "$CONTAINER_ID" /bin/bash < "${1}"
if [ $? -ne 0 ]; then
	# Exit using the variable, to make the build as failure in GitLab
	# CI.
	exit $BUILD_FAILURE_EXIT_CODE
fi