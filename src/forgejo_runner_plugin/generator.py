#!/usr/bin/env python3

from collections.abc import Generator, Iterator


class GeneratorWrapper[T, U]:
    def __init__(self, gen: Generator[T, None, U]) -> None:
        self.gen = gen

    def __iter__(self) -> Iterator[T]:
        self.returned = yield from self.gen
        return self.returned  # ty: ignore[invalid-return-type]
