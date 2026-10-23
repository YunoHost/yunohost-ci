#!/usr/bin/env python3

import argparse
import logging
from pathlib import Path

from forgejo_runner_plugin import init_server

from .runner import YunohostCIRunner


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--port", type=int, default=50051)
    parser.add_argument("-t", "--tempdir", type=Path, default=Path.cwd())
    args = parser.parse_args()
    port: int = args.port
    tempdir: Path = args.tempdir

    tempdir.mkdir(exist_ok=True)

    logging.getLogger().setLevel(logging.DEBUG)

    server = init_server("yunohost-ci", tempdir=tempdir, runner_class=YunohostCIRunner)
    server.add_insecure_port(f"[::]:{args.port}")
    server.start()
    print(f"Server started, listening on {port}")
    server.wait_for_termination()


if __name__ == "__main__":
    main()
