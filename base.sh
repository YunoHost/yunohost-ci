#!/usr/bin/env bash

# All Variables here: https://docs.gitlab.com/ee/ci/variables/predefined_variables.html#variables-reference, strating with CUSTOM_ENV_
#CUSTOM_ENV_CI_DEFAULT_BRANCH=stretch-unstable
#CUSTOM_ENV_CI_JOB_NAME=build1
#CUSTOM_ENV_CI_BUILD_STAGE=pre-postinstall
#CUSTOM_ENV_CI_JOB_STAGE=pre-postinstall
#CUSTOM_ENV_CI_BUILD_NAME=build1
#CUSTOM_ENV_CI_PROJECT_TITLE=yunohost
#CUSTOM_ENV_CI_RUNNER_EXECUTABLE_ARCH=linux/amd64
#CUSTOM_ENV_CI_PROJECT_NAMESPACE=yunohost
#CUSTOM_ENV_CI_COMMIT_REF_NAME=stretch-unstable
#CUSTOM_ENV_CI_COMMIT_REF_SLUG=stretch-unstable
#CUSTOM_ENV_CI_PROJECT_NAME=yunohost
#CUSTOM_ENV_CI_PROJECT_DIR=/builds/yunohost/yunohost
CONTAINER_ID="runner-$CUSTOM_ENV_CI_RUNNER_ID-project-$CUSTOM_ENV_CI_PROJECT_ID-concurrent-$CUSTOM_ENV_CI_CONCURRENT_PROJECT_ID-$CUSTOM_ENV_CI_JOB_ID"
ARCH="$(echo $CUSTOM_ENV_CI_RUNNER_EXECUTABLE_ARCH | cut -d'/' -f2)" # linux/amd64
DEFAULT_BRANCH="$CUSTOM_ENV_CI_DEFAULT_BRANCH"
CURRENT_VERSION=$(echo $CUSTOM_ENV_CI_DEFAULT_BRANCH | cut -d'-' -f2) # stretch-unstable, stretch-testing, stretch-stable...
CURRENT_BRANCH="$CUSTOM_ENV_CI_COMMIT_REF_NAME"
DEBIAN_VERSION=$(echo $CUSTOM_ENV_CI_COMMIT_REF_NAME | cut -d'-' -f1) # CUSTOM_ENV_CI_COMMIT_REF_NAME is the target branch of the MR: stretch-unstable, buster-unstable...
if [ -z "$DEBIAN_VERSION" ] || [ "$DEBIAN_VERSION" != "stretch" ] && [ "$DEBIAN_VERSION" != "buster" ]
then
    DEBIAN_VERSION="$(echo $CUSTOM_ENV_CI_DEFAULT_BRANCH | cut -d'-' -f1)" # stretch-unstable, buster-unstable...
    echo "Use the default debian version: $DEBIAN_VERSION"
fi
SNAPSHOT_NAME="$CUSTOM_ENV_CI_JOB_IMAGE"
if [ -z "$SNAPSHOT_NAME" ]
then
    SNAPSHOT_NAME="after-postinstall"
fi
PROJECT_DIR="$CUSTOM_ENV_CI_PROJECT_DIR"
PROJECT_NAME="$CUSTOM_ENV_CI_PROJECT_NAME"