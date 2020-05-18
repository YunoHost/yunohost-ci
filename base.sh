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
    echo "Use the default debian version: $DEBIAN_VERSION"
fi
SNAPSHOT_NAME="$CUSTOM_ENV_CI_JOB_IMAGE"
if [ -z "$SNAPSHOT_NAME" ]
then
    SNAPSHOT_NAME="after-postinstall"
fi
PROJECT_DIR="$CUSTOM_ENV_CI_PROJECT_DIR"
PROJECT_NAME="$CUSTOM_ENV_CI_PROJECT_NAME"

# For example yunohost-stretch-unstable
BASE_IMAGE="yunohost-$DEBIAN_VERSION-$CURRENT_VERSION"


YNH_DEPENDENCIES="debhelper python-psutil python-requests python-dnspython python-openssl python-miniupnpc python-dbus python-jinja2 python-toml python-packaging apt apt-transport-https nginx nginx-extras php-fpm php-ldap php-intl mariadb-server php-mysql php-mysqlnd openssh-server iptables fail2ban dnsutils bind9utils openssl ca-certificates netcat-openbsd iproute2 slapd ldap-utils sudo-ldap libnss-ldapd unscd libpam-ldapd dnsmasq avahi-daemon libnss-mdns resolvconf libnss-myhostname postfix postfix-ldap postfix-policyd-spf-perl postfix-pcre dovecot-core dovecot-ldap dovecot-lmtpd dovecot-managesieved dovecot-antispam rspamd opendkim-tools postsrsd procmail mailutils redis-server git curl wget cron unzip lsb-release haveged fake-hwclock equivs lsof whois python-publicsuffix"
BUILD_DEPENDENCIES="git-buildpackage postfix python-setuptools python-pip"