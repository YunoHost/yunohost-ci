#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/common.sh

# This script is called multiple times with different stage ($2) value
# This is documented in https://docs.gitlab.com/runner/executors/custom.html#run
JOB_STAGE=$2
if [[ "$JOB_STAGE" == "prepare_script" ]]
then
    echo "CI OPEN: $CUSTOM_ENV_CI_OPEN_MERGE_REQUESTS / CI PIPELINE SOURCE: $CUSTOM_ENV_CI_PIPELINE_SOURCE / REF NAME: $CUSTOM_ENV_CI_COMMIT_REF_NAME / COMMIT: $CUSTOM_ENV_CI_COMMIT_BRANCH, TAG: $CUSTOM_ENV_CI_COMMIT_TAG"
fi

###############################################################################

# This is the real 'important' logic bit
incus exec "$CONTAINER_NAME" /bin/bash < "${1}"

###############################################################################
err=$?
if [ $err -ne 0 ]; then
	echo "Exit with error code $err"
	# Exit using the variable, to make the build as failure in GitLab
	# CI.
	exit $BUILD_FAILURE_EXIT_CODE
fi
