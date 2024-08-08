#!/usr/bin/env bash

current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/common.sh

set -eo pipefail

wait_container()
{
    restart_container()
    {
        incus stop "$1" --timeout 30 || incus stop "$1" --force
        incus start "$1"
    }

    # Try to start the container 3 times.
    local max_try=3
    local i=0
    while [ $i -lt $max_try ]
    do
        i=$(( i +1 ))
        local failstart=0

        # Wait for container to start, we are using systemd to check this,
        # for the sake of brevity.
        for j in $(seq 1 10); do
            if incus exec "$1" -- /bin/bash -c "systemctl isolate multi-user.target" >/dev/null 2>/dev/null; then
                break
            fi

            if [ "$j" == "10" ]; then
                error 'Failed to start the container'
                failstart=1

                restart_container "$1"
            fi

            sleep 1s
        done

        # Wait for container to access the internet
        for j in $(seq 1 10); do
            if incus exec "$1" -- /bin/bash -c "! which wget > /dev/null 2>&1 || wget -q --spider http://github.com"; then
                break
            fi

            if [ "$j" == "10" ]; then
                error 'Failed to access the internet'
                failstart=1
                incus exec "$1" -- /bin/bash -c "echo 'resolv-file=/etc/resolv.dnsmasq.conf' > /etc/dnsmasq.d/resolvconf"
                incus exec "$1" -- /bin/bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.dnsmasq.conf"
                incus exec "$1" -- /bin/bash -c "sed -i 's/#IGNORE/IGNORE/g' /etc/default/dnsmasq"
                incus exec "$1" -- /bin/bash -c "systemctl restart dnsmasq"
                incus exec "$1" -- /bin/bash -c "journalctl -u dnsmasq -n 100 --no-pager"

                restart_container "$1"
            fi

            sleep 1s
        done

        # Wait dpkg
        for j in $(seq 1 10); do
            if  ! incus exec "$1" -- /bin/bash -c "fuser /var/lib/dpkg/lock > /dev/null 2>&1" &&
                ! incus exec "$1" -- /bin/bash -c "fuser /var/lib/dpkg/lock-frontend > /dev/null 2>&1" &&
                ! incus exec "$1" -- /bin/bash -c "fuser /var/cache/apt/archives/lock > /dev/null 2>&1"; then
                break
            fi

            if [ "$j" == "10" ]; then
                error 'Waiting too long for lock release'
                failstart=1

                restart_container "$1"
            fi

            sleep 1s
        done

        # Has started and has access to the internet
        if [ $failstart -eq 0 ]
        then
            break
        fi

        # Fail if the container failed to start
        if [ $i -eq $max_try ] && [ $failstart -eq 1 ]
        then
            # Inform GitLab Runner that this is a system failure, so it
            # should be retried.
            exit "$SYSTEM_FAILURE_EXIT_CODE"
        fi
    done
}

# trap any error, and mark it as a system failure.
trap "exit $SYSTEM_FAILURE_EXIT_CODE" ERR

###############################################################################

if ! incus info "$CONTAINER_NAME" >/dev/null 2>/dev/null ; then
    info "Starting $CONTAINER_NAME from $BASE_IMAGE ..."

    # Force the usage of the fingerprint because otherwise for some reason lxd won't use the newer version
    # available even though it's aware it exists -_-
    BASE_HASH="$(incus image list yunohost:$BASE_IMAGE --format json | jq -r '.[].fingerprint')"

    # NB: this image comes from the 'common' image repository shared with the appci, ynh-dev etc
    incus launch yunohost:$BASE_HASH $CONTAINER_NAME
    sleep 2
fi

# Start the container if it's not running
if [ "$(incus info $CONTAINER_NAME | grep Status | awk '{print tolower($2)}')" != "running" ]; then
    incus start $CONTAINER_NAME
fi

if [[ $IMAGE == "build-and-lint" ]]
then
    exit 0
fi

incus exec $CONTAINER_NAME dhclient eth0

info "Waiting for $CONTAINER_NAME to finish booting and making sure it's connected to the internetz..."

wait_container $CONTAINER_NAME

success "$CONTAINER_NAME started properly"
