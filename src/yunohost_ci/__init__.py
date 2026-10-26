#!/usr/bin/env python3

import argparse
import logging
from concurrent import futures
from pathlib import Path

import grpc

from forgejo_runner_plugin import ForgejoPlugin, init_grpc_server

from .runner import YunohostCIRunner


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--port", type=int, default=50051)
    parser.add_argument("-t", "--tempdir", type=Path, default=Path.cwd())
    args = parser.parse_args()
    port: int = args.port
    tempdir: Path = args.tempdir

    tempdir.mkdir(exist_ok=True)

    logging.basicConfig()
    logging.getLogger("forgejo_plugin").setLevel(logging.INFO)
    logging.getLogger("incus").setLevel(logging.INFO)
    logging.getLogger().setLevel(logging.DEBUG)

    duration_10h = 1000*60*60*10

    server_options = [
        # ("grpc.keepalive_time_ms", 20000),
        # ("grpc.keepalive_timeout_ms", 10000),
        # ("grpc.http2.min_ping_interval_without_data_ms", 5000),
        ("grpc.max_connection_idle_ms", duration_10h),
        ("grpc.max_connection_age_ms", duration_10h),
        ("grpc.max_connection_age_grace_ms", duration_10h),
        ("grpc.http2.max_pings_without_data", duration_10h),
        ("grpc.keepalive_permit_without_calls", duration_10h),
    ]

    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10), options=server_options)
    plugin = ForgejoPlugin("yunohost-ci", tempdir=tempdir, runner_class=YunohostCIRunner)
    init_grpc_server(server, plugin)
    server.add_insecure_port(f"[::]:{args.port}")
    server.start()
    print(f"Server started, listening on {port}")
    server.wait_for_termination()


if __name__ == "__main__":
    main()
