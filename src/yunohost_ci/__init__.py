#!/usr/bin/env python3

import argparse
import logging
from pathlib import Path

from .plugin import init_server


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--port", type=int, default=50051)
    parser.add_argument("-t", "--tempdir", type=Path, default=Path.cwd())
    args = parser.parse_args()
    port: int = args.port
    tempdir: Path = args.tempdir

    tempdir.mkdir(exist_ok=True)

    logging.getLogger().setLevel(logging.DEBUG)

    server = init_server(tempdir=tempdir)
    server.add_insecure_port(f"[::]:{args.port}")
    server.start()
    print(f"Server started, listening on {port}")
    server.wait_for_termination()


if __name__ == "__main__":
    main()
