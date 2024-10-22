#!/usr/bin/env bash

NORMAL=$(printf '\033[0m')
BOLD=$(printf '\033[1m')
RED=$(printf '\033[31m')
GREEN=$(printf '\033[32m')
ORANGE=$(printf '\033[33m')
BLUE=$(printf '\033[34m')

function success() { echo "[${BOLD}${GREEN} OK ${NORMAL}] ${1}"; }
function info() { echo "[${BOLD}${BLUE}INFO${NORMAL}] ${1}"; }
function warn() { echo "[${BOLD}${ORANGE}WARN${NORMAL}] ${1}" 2>&1; }
function error() { echo "[${BOLD}${RED}FAIL${NORMAL}] ${1}"  2>&1; }

# All Variables here: https://docs.gitlab.com/ee/ci/variables/predefined_variables.html#variables-reference, strating with CUSTOM_ENV_

DEFAULT_BRANCH="$CUSTOM_ENV_CI_DEFAULT_BRANCH"
CURRENT_BRANCH="${CUSTOM_ENV_CI_COMMIT_REF_NAME:-$DEFAULT_BRANCH}" # CUSTOM_ENV_CI_COMMIT_REF_NAME is the target branch of the MR

IMAGE="${CUSTOM_ENV_CI_JOB_IMAGE:-after-install}"

[[ -n "$CUSTOM_ENV_YNH_DEBIAN" ]] || { echo "Undefined ynh debian var?"; exit 1; }
DEBIAN=$CUSTOM_ENV_YNH_DEBIAN

if [[ "$DEBIAN" == "bullseye" ]]
then
    RELEASE="stable"
else
    RELEASE="testing"
fi

BASE_IMAGE="yunohost/${DEBIAN}-${RELEASE}/${IMAGE}"

if [[ $IMAGE == "build-and-lint" ]]
then
    CONTAINER_NAME="$DEBIAN-build-and-lint"
else
    CONTAINER_NAME="job-$CUSTOM_ENV_CI_JOB_ID-$CUSTOM_ENV_CI_JOB_NAME_SLUG"
fi
