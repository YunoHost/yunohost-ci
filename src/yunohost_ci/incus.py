#!/usr/bin/env python3

import io
import os
import platform
import selectors
import subprocess
from collections.abc import Generator
from pathlib import Path, PurePath
from typing import Any, cast

import yaml


class Incus:
    def __init__(self) -> None:
        pass

    def arch(self) -> str:
        plat = platform.machine()
        if plat in ["x86_64", "amd64"]:
            return "amd64"
        if plat in ["arm64", "aarch64"]:
            return "arm64"
        if plat in ["armhf"]:  # noqa: FURB171
            return "armhf"
        msg = f"Unknown platform {plat}!"
        raise RuntimeError(msg)

    def _run(self, *args: str, **kwargs: Any) -> str:  # noqa: ANN401
        command = ["incus", *args]
        print(command)
        result: bytes = subprocess.check_output(command, **kwargs)
        return result.decode("utf-8")

    def _run_yielding(self, *args: str, **kwargs: Any) -> Generator[tuple[bytes, bytes], None, int]:  # noqa: ANN401
        command = ["incus", *args]
        print(command)

        proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=False, **kwargs)
        out = cast("io.BytesIO", proc.stdout)
        err = cast("io.BytesIO", proc.stderr)
        sel = selectors.DefaultSelector()
        sel.register(out, selectors.EVENT_READ)
        sel.register(err, selectors.EVENT_READ)

        while proc.poll() is None:
            out, err = b"", b""
            for key, _ in sel.select():
                file = cast("io.BytesIO", key.fileobj)
                if not (data := file.read1()):
                    break
                if file is out:
                    out += data
                else:
                    err += data
            yield out, err

        return proc.returncode

    def instance_stopped(self, name: str) -> bool:
        if not self.instance_exists(name):
            msg = f"Trying to check status of non existing instance {name}"
            raise RuntimeError(msg)
        res = yaml.safe_load(self._run("info", name))
        return str(res["Status"]) == "STOPPED"

    def instance_exists(self, name: str) -> bool:
        res = yaml.safe_load(self._run("list", "-f", "yaml"))
        instance_names = [instance["name"] for instance in res]
        return name in instance_names

    def instance_start(self, name: str) -> None:
        self._run("start", name)

    def instance_stop(self, name: str) -> None:
        self._run("stop", name)

    def instance_delete(self, name: str) -> None:
        self._run("delete", name, "--force")

    def launch(self, image_name: str, instance_name: str, *args: str) -> None:
        self._run("launch", image_name, instance_name, *args)

    def push_file(self, instance_name: str, source: Path, target: str) -> None:
        self._run("file", "push", "-pr", str(source), f"{instance_name}{target}")
        os.sync()

    def pull_file(self, instance_name: str, source: str, target: Path) -> None:
        self._run("file", "pull", "-pr", f"{instance_name}{source}", str(target))
        os.sync()

    def create_file(
        self,
        instance_name: str,
        path: str,
        *,
        directory: bool = False,
        user: str | None = None,
        group: str | None = None,
        parents: bool = False,
    ) -> None:
        user_args = ["--uid", user] if user else []
        group_args = ["--gid", group] if group else []
        type_args = ["--type", "directory" if directory else "file"]

        if parents:
            self._run(
                "file", "create", f"{instance_name}{PurePath(path).parent}", "--type", "directory", "--create-dirs"
            )
        # do not use --create-dirs to avoid user having permissions on parent dirs
        self._run("file", "create", f"{instance_name}{path}", *user_args, *group_args, *type_args)

    def execute(
        self,
        instance_name: str,
        *args: str,
        user: str | None = None,
        cwd: str | None = None,
        env: dict[str, str] | None = None,
    ) -> Generator[tuple[bytes, bytes], None, int]:
        user_args = ["--user", user] if user else []
        cwd_args = ["--cwd", cwd] if cwd else []
        env_args: list[str] = []
        for key, val in env.items() if env else {}:
            env_args.extend(["--env", f"{key}={val}"])

        cmd = ["exec", instance_name, *user_args, *cwd_args, *env_args, "--", *args]
        result = yield from self._run_yielding(*cmd)
        return result

    def publish(self, instance_name: str, image_alias: str, properties: dict[str, str]) -> None:
        properties_list = [f"{key}={value}" for key, value in properties.items()]
        self._run("publish", instance_name, "--alias", image_alias, *properties_list)

    def image_export(self, image_alias: str, image_target: str, target_dir: Path) -> None:
        self._run("image", "export", image_alias, image_target, cwd=target_dir)

    def image_exists(self, alias: str) -> bool:
        res = yaml.safe_load(self._run("image", "list", "-f", "yaml"))
        image_aliases = [alias["name"] for image in res for alias in image["aliases"]]
        return alias in image_aliases

    def image_info(self, image_alias: str) -> dict[str, Any] | None:
        try:
            res = yaml.safe_load(self._run("image", "info", image_alias))
        except subprocess.CalledProcessError:
            return None
        return res

    def image_alias_exists(self, alias: str) -> bool:
        res = yaml.safe_load(self._run("image", "alias", "list", "-f", "yaml"))
        aliases = [alias["name"] for alias in res]
        return alias in aliases

    def image_delete(self, alias: str) -> None:
        self._run("image", "delete", alias)

    def image_download(self, alias: str) -> None:
        if self.image_alias_exists(alias):
            self.image_delete(alias)
        self._run("image", "copy", alias, "local:")
