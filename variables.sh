#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/prints.sh

# All Variables here: https://docs.gitlab.com/ee/ci/variables/predefined_variables.html#variables-reference, strating with CUSTOM_ENV_

ARCH="$(echo $CUSTOM_ENV_CI_RUNNER_EXECUTABLE_ARCH | cut -d'/' -f2)" # linux/amd64
DEFAULT_BRANCH="$CUSTOM_ENV_CI_DEFAULT_BRANCH"

CURRENT_BRANCH="$CUSTOM_ENV_CI_COMMIT_REF_NAME" # CUSTOM_ENV_CI_COMMIT_REF_NAME is the target branch of the MR
LAST_CHANGELOG_ENTRY=$(curl https://gitlab.com/yunohost/yunohost/-/raw/$CURRENT_BRANCH/debian/changelog --silent | head -n 1) # yunohost (4.2) unstable; urgency=low
CURRENT_VERSION=$(echo $LAST_CHANGELOG_ENTRY | cut -d' ' -f3 | tr -d ';') # stable, testing, unstable

DEBIAN_VERSION_NUMBER=$(echo $LAST_CHANGELOG_ENTRY | cut -d' ' -f2 | tr -d '(' | tr -d ')' | cut -d'.' -f1) # 11, 12

declare -A DEBIAN_VERSION_TABLE
DEBIAN_VERSION_TABLE=(["11"]="bullseye" ["12"]="bookworm")

DEBIAN_VERSION="${DEBIAN_VERSION_TABLE[$DEBIAN_VERSION_NUMBER]}"

SNAPSHOT_NAME="$CUSTOM_ENV_CI_JOB_IMAGE"
if [ -z "$SNAPSHOT_NAME" ]
then
	SNAPSHOT_NAME="after-install"
fi
PROJECT_DIR="$CUSTOM_ENV_CI_PROJECT_DIR"
PROJECT_NAME="$CUSTOM_ENV_CI_PROJECT_NAME"

# For example yunohost-buster-unstable
BASE_IMAGE="yunohost-$DEBIAN_VERSION-$CURRENT_VERSION"

CONTAINER_IMAGE="$BASE_IMAGE-runner-$CUSTOM_ENV_CI_RUNNER_ID-project-$CUSTOM_ENV_CI_PROJECT_ID-concurrent-$CUSTOM_ENV_CI_CONCURRENT_PROJECT_ID"