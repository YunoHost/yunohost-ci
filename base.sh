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
	SNAPSHOT_NAME="after-install"
fi
PROJECT_DIR="$CUSTOM_ENV_CI_PROJECT_DIR"
PROJECT_NAME="$CUSTOM_ENV_CI_PROJECT_NAME"

# For example yunohost-stretch-unstable
BASE_IMAGE="yunohost-$DEBIAN_VERSION-$CURRENT_VERSION"


YNH_DEPENDENCIES="apt apt-transport-https apt-utils avahi-daemon bind9utils ca-certificates cron curl debhelper dnsmasq dnsutils dovecot-antispam dovecot-core dovecot-ldap dovecot-lmtpd dovecot-managesieved equivs fail2ban fake-hwclock git haveged inetutils-ping iproute2 iptables jq ldap-utils libconvert-asn1-perl libdbd-ldap-perl libestr0 libfastjson4 libgssapi-perl libjq1 liblogging-stdlog0 liblognorm5 libmcrypt4 libnet-ldap-perl libnss-ldapd libnss-mdns libnss-myhostname libonig4 libopts25 libpam-ldapd libyaml-0-2 logrotate lsb-release lsof lua5.1 lua-bitop lua-event lua-expat lua-filesystem lua-json lua-ldap lua-lpeg lua-rex-pcre lua-sec lua-socket lua-zlib mailutils mariadb-server netcat-openbsd nginx nginx-extras ntp opendkim-tools openssh-server openssl php7.0-curl php7.0-gd php7.0-mbstring php7.0-mcrypt php7.0-xml php-curl php-fpm php-gd php-gettext php-intl php-ldap php-mbstring php-mcrypt php-mysql php-mysqlnd php-pear php-php-gettext php-xml postfix postfix-ldap postfix-pcre postfix-policyd-spf-perl postsrsd procmail python-argcomplete python-bottle python-dbus python-dnspython python-gevent python-gevent-websocket python-greenlet python-jinja2 python-ldap python-miniupnpc python-openssl python-packaging python-psutil python-publicsuffix python-requests python-toml python-tz python-yaml redis-server resolvconf rspamd rsyslog slapd sudo-ldap unattended-upgrades unscd unzip wget whois"
BUILD_DEPENDENCIES="git-buildpackage postfix python-setuptools python-pip"
PIP_PKG="mock pip pytest pytest-mock pytest-sugar requests-mock tox"