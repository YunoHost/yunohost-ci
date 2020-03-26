current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/utils.sh # Get utils functions.

for debian_version in "stretch" "buster"
do
    for ynh_version in "stable" "testing" "unstable"
    do
        for snapshot in "before-install" "before-postinstall" "after-postinstall"
        do
            local image="yunohost-$debian_version-$ynh_version-$snapshot"

            update_image $image
        done
    done
done