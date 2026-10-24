#!/usr/bin/env python3

import logging
import shutil
import subprocess
from collections.abc import Generator
from pathlib import Path, PurePath
from typing import final

from forgejo_runner_plugin import ForgejoActionRunner

from .incus import Incus


@final
class YunohostCIRunner(ForgejoActionRunner):
    def __init__(self, name: str, image: str, label: str, timeout: int, workdir: Path) -> None:
        self._workdir = workdir
        self.name = name
        self.image = image
        self.label = label
        self.timeout = timeout
        self.root_path: PurePath = workdir
        self.act_path: PurePath = workdir
        self.tool_cache_path: PurePath = workdir
        self.temp_path: PurePath = workdir
        self._workdir.mkdir(exist_ok=True)

        self.image_name = self.image
        self.instance_name = self.name

    def _real_path(self, target: PurePath) -> Path:
        return self._workdir / target.relative_to("/") if target.is_absolute() else Path(target)

    @classmethod
    def create(
        cls,
        name: str,
        image: str,
        label: str,
        capabilities: tuple[list[str], list[str]],
        options: dict[str, str],
        timeout: int,
        workdir: Path,
    ) -> "YunohostCIRunner":
        return YunohostCIRunner(name, image, label, timeout, workdir)

    def start(self) -> Generator[str, None, int]:
        yield f"Starting container {self.instance_name}...\n"
        incus = Incus()
        if not incus.instance_exists(self.instance_name):
            logging.info(f"Starting container {self.instance_name} from {self.image_name}...")
            base_hash = incus.image_info(self.image_name)["Fingerprint"]
            args = ["-c", "security.privileged=true", "-c", "security.nesting=true"]
            incus.launch(base_hash, self.instance_name, *args)

        if incus.instance_stopped(self.instance_name):
            incus.instance_start(self.instance_name)
        return 0

    def cleanup(self) -> None:
        incus = Incus()
        incus.instance_stop(self.instance_name)
        logging.info(f"Deleting container {self.instance_name}")
        incus.instance_delete(self.instance_name)

    def push(self, source: Path, target: PurePath) -> None:
        print(f"Copying {source} to incus container {target}")
        real_target = self._real_path(target)
        real_target.parent.mkdir(exist_ok=True)
        Incus().push_file(self.instance_name, source, str(target))

    def pull(self, source: PurePath, target: Path) -> None:
        target.parent.mkdir(exist_ok=True)
        Incus().pull_file(self.instance_name, str(source), target)
        # real_source = self._real_path(source)
        # real_source.parent.mkdir(exist_ok=True)
        # if real_source.is_dir():
        #     shutil.copytree(real_source, target)
        # else:
        #     shutil.copy(real_source, target)

    def exec(
        self, command: list[str], *, user: str, workdir: PurePath, env: dict[str, str]
    ) -> Generator[tuple[str, str], None, int]:
        print(f"executing {command}...")
        result = yield from Incus().execute(self.instance_name, *command, user=user, cwd=str(workdir), env=env)
        return result
