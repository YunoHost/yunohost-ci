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

LAST_CHANGELOG_ENTRY=$(curl $CUSTOM_ENV_CI_PROJECT_URL/-/raw/$CURRENT_BRANCH/debian/changelog --silent | head -n 1) # yunohost (4.2) unstable; urgency=low
DEBIAN_VERSION_NUMBER=$(echo $LAST_CHANGELOG_ENTRY | cut -d' ' -f2 | tr -d '(' | tr -d ')' | cut -d'.' -f1) # 11, 12
if [[ "$DEBIAN_VERSION_NUMBER" == "11" ]]
then
	BASE_IMAGE="ynh-$IMAGE-bullseye-amd64-stable-base"
elif [[ "$DEBIAN_VERSION_NUMBER" == "12" ]]
then
	BASE_IMAGE="ynh-$IMAGE-bookworm-amd64-testing-base"
elif [[ "$DEBIAN_VERSION_NUMBER" == "13" ]]
then
	# Upcoming someday™
	BASE_IMAGE="ynh-$IMAGE-trixie-amd64-unstable-base"
else
	echo "Uhoh, unknown debian version $DEBIAN_VERSION_NUMBER"
	exit 1
fi

CONTAINER_NAME="job-$CUSTOM_ENV_CI_JOB_ID-$CUSTOM_ENV_CI_JOB_NAME_SLUG"
