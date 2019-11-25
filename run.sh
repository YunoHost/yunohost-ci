#!/usr/bin/env bash

# /opt/lxd-executor/run.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base.sh # Get variables from base.

create_sym_link() {
	local DEST=$1
	local LINK=$2
	# Remove current sources if not a symlink
	[ -L "$LINK" ] || rm -rf $LINK
	# Symlink from Git repository
	lxc exec "$CONTAINER_ID" -- sh -c "ln -sfn $DEST $LINK"
}

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
				# bin
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/bin/yunohost" "/usr/bin/yunohost"
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/bin/yunohost-api" "/usr/bin/yunohost-api"

				# data
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/data/actionsmap/yunohost.yml" "/usr/share/moulinette/actionsmap/yunohost.yml"
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/data/hooks" "/usr/share/yunohost/hooks"
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/data/templates" "/usr/share/yunohost/templates"
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/data/helpers" "/usr/share/yunohost/helpers"
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/data/helpers.d" "/usr/share/yunohost/helpers.d"
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/data/other" "/usr/share/yunohost/yunohost-config/moulinette"
				# debian
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/debian/conf/pam/mkhomedir" "/usr/share/pam-configs/mkhomedir"

				# lib
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/lib/metronome/modules/ldap.lib.lua" "/usr/lib/metronome/modules/ldap.lib.lua"
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/lib/metronome/modules/mod_auth_ldap2.lua" "/usr/lib/metronome/modules/mod_auth_ldap2.lua"
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/lib/metronome/modules/mod_legacyauth.lua" "/usr/lib/metronome/modules/mod_legacyauth.lua"
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/lib/metronome/modules/mod_storage_ldap.lua" "/usr/lib/metronome/modules/mod_storage_ldap.lua"
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/lib/metronome/modules/vcard.lib.lua" "/usr/lib/metronome/modules/vcard.lib.lua"

				# src
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/src/yunohost" "/usr/lib/moulinette/yunohost"

				# locales
				create_sym_link "$CUSTOM_ENV_CI_PROJECT_DIR/locales" "/usr/lib/moulinette/yunohost/locales"
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