current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $current_dir/utils.sh # Get utils functions.

for debian_version in "stretch" "buster"
do
    for ynh_version in "stable" "testing" "unstable"
    do
        base_image="yunohost-$debian_version-$ynh_version"

        rebuild_base_containers $base_image
    done
done