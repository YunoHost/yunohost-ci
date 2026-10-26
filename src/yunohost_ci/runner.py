#!/usr/bin/env python3

import logging
import shlex
import shutil
from collections.abc import Generator
from pathlib import Path, PurePath
from typing import final

from forgejo_runner_plugin import ForgejoActionRunner

from .incus import Incus

logger = logging.getLogger("yunohost-ci")


@final
class YunohostCIRunner(ForgejoActionRunner):
    def __init__(self, name: str, image: str, label: str, timeout: int, workdir: Path) -> None:
        self.workdir = workdir
        self.name = name
        self.image = image
        self.label = label
        self.timeout = timeout
        self.root_path: PurePath = PurePath("/action/root-path")
        self.act_path: PurePath = PurePath("/action/act-path")
        self.tool_cache_path: PurePath = PurePath("/action/tool-cache")
        self.temp_path: PurePath = PurePath("/action/temp")
        self.workdir.mkdir(parents=True, exist_ok=True)

        self.image_name = self.image

        name_parts = self.name.lower().split("_")
        self.instance_name = f"{name_parts[0]}-{name_parts[1][0:10]}-{name_parts[2]}"

    def _real_path(self, target: PurePath) -> Path:
        return self.workdir / target.relative_to("/") if target.is_absolute() else Path(target)

    @classmethod
    def create(
        cls,
        name: str,
        image: str,
        label: str,
        capabilities: tuple[list[str], list[str]],  # noqa: ARG003
        options: dict[str, str],  # noqa: ARG003
        timeout: int,
        workdir: Path,
    ) -> "YunohostCIRunner":
        return YunohostCIRunner(name, image, label, timeout, workdir)

    def start(self) -> Generator[bytes, None, int]:
        msg = f"Starting container {self.instance_name}..."
        logger.info(msg)
        yield f"{msg}\n".encode()
        incus = Incus()
        if not incus.instance_exists(self.instance_name):
            remote_image = "yunohost:" + self.image_name
            logger.info(f"Starting container {self.instance_name} from {self.image_name}...")
            # info = incus.image_info(remote_image)
            # if info is None:
            #     msg = f"Could not start: image not found: {remote_image}"
            #     raise RuntimeError(msg)
            # base_hash = info["Fingerprint"]
            args = ["-c", "security.privileged=true", "-c", "security.nesting=true"]
            incus.launch(remote_image, self.instance_name, *args)

        if incus.instance_stopped(self.instance_name):
            incus.instance_start(self.instance_name)
        return 0

    def cleanup(self) -> None:
        incus = Incus()
        incus.instance_stop(self.instance_name)
        logger.info(f"Deleting container {self.instance_name}")
        incus.instance_delete(self.instance_name)
        shutil.rmtree(self.workdir)

    def push(self, source: Path, target: PurePath) -> None:
        logger.info(f"Copying {source} to incus container {target}")
        if source.is_dir():
            if source.name != target.name:
                msg = "Invalid usage: source and target shall have the same name if a directory."
                raise RuntimeError(msg)
            target = target.parent
        Incus().push_file(self.instance_name, source, target)

    def pull(self, source: PurePath, target: Path) -> None:
        logger.info(f"Copying {target} from incus container {target}")
        target.parent.mkdir(exist_ok=True)
        Incus().pull_file(self.instance_name, source, target)

    def exec(
        self, command: list[str], *, user: str, workdir: PurePath, env: dict[str, str]
    ) -> Generator[tuple[bytes, bytes], None, int]:
        logger.debug(f"Executing {shlex.join(command)}...")
        Incus().create_file(self.instance_name, workdir, directory=True, user=user, parents=True)
        result = yield from Incus().execute(self.instance_name, *command, user=user, cwd=workdir, env=env)
        return result
