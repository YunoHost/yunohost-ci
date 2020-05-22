# YunoHost-CI: Gitlab runner for YunoHost Core

## Introduction
`yunohost-ci` is a [custom executor](https://docs.gitlab.com/runner/executors/custom.html) for [Gitlab Runner](https://docs.gitlab.com/runner/).

It uses LXD/LXC environment to run tests on YunoHost Core. Tests must be written in file [`.gitlab-ci.yml`](https://docs.gitlab.com/ee/ci/yaml/) on each YunoHost Core repository to test.

## Setup `YunoHost-CI`

First you need to install the system dependencies.

`yunohost-ci` essentially requires Git and the LXD/LXC ecosystem. 

For Gitlab Runner, you can find doc [here](https://docs.gitlab.com/runner/install/linux-repository.html). On Debian-based system, you can add GitLab’s official repository:
```bash
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
```

Then install Gitlab Runner (min version: 12.1):
```bash
sudo apt-get install gitlab-runner
```

Then, on a Debian-based system (regular Debian, Ubuntu, Mint ...), LXD can be installed using `snapd`. On other systems like Archlinux, you will probably also be able to install `snapd` using the system package manager (or even `lxd` directly).

```bash
sudo apt install git snapd
sudo snap install lxd

# Adding lxc/lxd to /usr/local/bin to make sure we can use them easily even
# with sudo for which the PATH is defined in /etc/sudoers and probably doesn't
# include /snap/bin
sudo ln -s /snap/bin/lxc /usr/local/bin/lxc
sudo ln -s /snap/bin/lxd /usr/local/bin/lxd
```

Then you shall initialize LXD which will ask you several questions. Usually answering the default (just pressing enter) to all questions is fine.

```bash
sudo lxd init
```

## Register `YunoHost-CI`

To use this runner, you must register the Gitlab Runner that you just installed (you can register in on several projects, or on the group that contains all projects). But, you have to **disable the shared runner** to only use this runner and not "Official" that is using a docker executor.

You can follow this [official doc](https://docs.gitlab.com/runner/register/) to register it. The only think to change is the point number 6, where you have to choose `custom`.

After that, clone this repo where you want, and be sure that scripts `base.sh` `cleanup.sh` `prepare.sh` and `run.sh` have the execution permission.

Finally, edit the file `/etc/gitlab-runner/config.toml` to add `builds_dir`, `cache_dir`, and all the `[runners.custom]` section. Your file should looks like this:

```toml
concurrent = 1
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "yunohost-ci"
  url = "https://gitlab.com/" # Gitlab URL
  token = "[SECRET-TOKEN]" # Very private token
  executor = "custom"
  builds_dir = "/builds" # Will be created if doesn't exist
  cache_dir = "/cache" # Will be created if doesn't exist
  [runners.custom]
    prepare_exec = "/opt/yunohost-ci/prepare.sh" # Path to a bash script to create lxd container and download dependencies.
    run_exec = "/opt/yunohost-ci/run.sh" # Path to a bash script to run script inside the container.
    cleanup_exec = "/opt/yunohost-ci/cleanup.sh" # Path to bash script to delete container.
```

## Using images

Use the field `image` to switch between `before-install` or `after-install` (`after-install` by default) for example:
- `image: after-install` to use the image after the postinstall of Yunohost
- `image: before-install` to use the image before the installation of YunoHost

## TODO

- Support more YunoHost Core projects (for now only `yunohost` is supported, not `moulinette`...)
- Git pull this repo before running tests to keep these files up-to-date.
