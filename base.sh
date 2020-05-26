#!/usr/bin/env bash

# All Variables here: https://docs.gitlab.com/ee/ci/variables/predefined_variables.html#variables-reference, strating with CUSTOM_ENV_

CONTAINER_ID="runner-$CUSTOM_ENV_CI_RUNNER_ID-project-$CUSTOM_ENV_CI_PROJECT_ID-concurrent-$CUSTOM_ENV_CI_CONCURRENT_PROJECT_ID-$CUSTOM_ENV_CI_JOB_ID"
ARCH="$(echo $CUSTOM_ENV_CI_RUNNER_EXECUTABLE_ARCH | cut -d'/' -f2)" # linux/amd64
DEFAULT_BRANCH="$CUSTOM_ENV_CI_DEFAULT_BRANCH"
CURRENT_VERSION=$(echo $CUSTOM_ENV_CI_DEFAULT_BRANCH | cut -d'-' -f2) # stretch-unstable, stretch-testing, stretch-stable...
CURRENT_BRANCH="$CUSTOM_ENV_CI_COMMIT_REF_NAME"
DEBIAN_VERSION=$(echo $CUSTOM_ENV_CI_COMMIT_REF_NAME | cut -d'-' -f1) # CUSTOM_ENV_CI_COMMIT_REF_NAME is the target branch of the MR: stretch-unstable, buster-unstable...
if [ -z "$DEBIAN_VERSION" ] || [ "$DEBIAN_VERSION" != "stretch" ] && [ "$DEBIAN_VERSION" != "buster" ]
then
	DEBIAN_VERSION="$(echo $CUSTOM_ENV_CI_DEFAULT_BRANCH | cut -d'-' -f1)" # stretch-unstable, buster-unstable...
	info "Use the default debian version: $DEBIAN_VERSION"
fi
SNAPSHOT_NAME="$CUSTOM_ENV_CI_JOB_IMAGE"
if [ -z "$SNAPSHOT_NAME" ]
then
	SNAPSHOT_NAME="after-install"
fi
PROJECT_DIR="$CUSTOM_ENV_CI_PROJECT_DIR"
PROJECT_NAME="$CUSTOM_ENV_CI_PROJECT_NAME"

# For example yunohost-stretch-unstable
BASE_IMAGE="yunohost-$DEBIAN_VERSION-$CURRENT_VERSION"
