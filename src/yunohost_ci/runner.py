#!/usr/bin/env python3

import shutil
import subprocess
from collections.abc import Generator
from pathlib import Path, PurePath

from forgejo_runner_plugin import ForgejoActionRunner


class YunohostCIRunner(ForgejoActionRunner):
    def __init__(self, workdir: Path) -> None:
        self._workdir = workdir
        self.root_path: PurePath = workdir
        self.act_path: PurePath = workdir
        self.tool_cache_path: PurePath = workdir
        self.temp_path: PurePath = workdir

    def _real_path(self, target: PurePath) -> Path:
        return self._workdir / target.relative_to("/") if target.is_absolute() else Path(target)

    def create(self) -> None:
        self._workdir.mkdir(exist_ok=True)

    def cleanup(self) -> None:
        # shutil.rmtree(self.workdir)
        pass

    def start(self) -> Generator[str, None, int]:
        yield "Starting yunohost ci runner..."
        return 0

    def push(self, source: Path, target: PurePath) -> None:
        print(f"Copying {source} to incus container {target}")
        real_target = self._real_path(target)
        real_target.parent.mkdir(exist_ok=True)
        shutil.copytree(source, real_target, dirs_exist_ok=True)
        # for file in source.iterdir():
        #     print(file)

    def pull(self, source: PurePath, target: Path) -> None:
        target.parent.mkdir(exist_ok=True)
        real_source = self._real_path(source)
        real_source.parent.mkdir(exist_ok=True)
        if real_source.is_dir():
            shutil.copytree(real_source, target)
        else:
            shutil.copy(real_source, target)

    def exec(
        self, command: list[str], *, user: str, workdir: PurePath, env: dict[str, str]
    ) -> Generator[tuple[str, str], None, int]:
        print(f"executing {command}...")
        result = subprocess.run(command, shell=False, capture_output=True, check=False)
        for line in result.stdout.decode().splitlines(keepends=True):
            yield (line, "")
        for line in result.stderr.decode().splitlines(keepends=True):
            yield ("", line)
        return result.returncode
