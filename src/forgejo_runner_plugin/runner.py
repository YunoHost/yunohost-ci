#!/usr/bin/env python3

from abc import abstractmethod
from collections.abc import Generator
from pathlib import Path, PurePath
from typing import Protocol


class ForgejoActionRunner(Protocol):
    workdir: Path
    root_path: PurePath
    act_path: PurePath
    tool_cache_path: PurePath
    temp_path: PurePath

    @classmethod
    @abstractmethod
    def create(
        cls,
        name: str,
        image: str,
        label: str,
        capabilities: tuple[list[str], list[str]],
        options: dict[str, str],
        timeout: int,
        workdir: Path,
    ) -> "ForgejoActionRunner": ...

    @abstractmethod
    def cleanup(self) -> None: ...

    @abstractmethod
    def start(self) -> Generator[bytes, None, int]: ...

    @abstractmethod
    def push(self, source: Path, target: PurePath) -> None: ...

    @abstractmethod
    def pull(self, source: PurePath, target: Path) -> None: ...

    @abstractmethod
    def exec(
        self, command: list[str], *, user: str, workdir: PurePath, env: dict[str, str]
    ) -> Generator[tuple[bytes, bytes], None, int]: ...
