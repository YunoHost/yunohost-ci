#!/usr/bin/env python3

import shutil
from collections.abc import Generator
from pathlib import Path, PurePath


class YunohostCIRunner:
    def __init__(self, workdir: Path) -> None:
        self.workdir = workdir

    def create(self) -> None:
        self.workdir.mkdir(exist_ok=True)

    def cleanup(self) -> None:
        # shutil.rmtree(self.workdir)
        pass

    def start(self) -> Generator[str, None, int]:
        yield "Starting yunohost ci runner..."
        return 0

    def push_dir(self, source: Path, target: PurePath) -> None:
        print(f"Copying {source} to incus container {target}")
        if 
        dst = self.workdir / target.relative_to("/")
        dst.parent.mkdir(exist_ok=True)
        shutil.copytree(source, dst, dirs_exist_ok=True)
        # for file in source.iterdir():
        #     print(file)

    def pull_dir(self, source: PurePath, target: Path) -> None:
        target.parent.mkdir(exist_ok=True)
        shutil.copytree(self.workdir / source.relative_to("/"), target)

    def exec(self, command: list[str], *, user: str, workdir: PurePath, env: dict[str, str]) -> Generator[str, None, int]:
        print(f"executing {command}...")
        yield f"Execution line for {command}"
        return 0
