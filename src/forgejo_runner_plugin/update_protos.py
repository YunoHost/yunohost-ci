#!/usr/bin/env python3

from pathlib import Path

import httpx2
from grpc_tools import protoc

PROTOS_DIR = Path(__file__).parent / "protos"

PROTOS: dict[str, str] = {
    "plugin.proto": "https://code.forgejo.org/forgejo/runner/raw/branch/main/act/plugin/proto/v1alpha/plugin.proto",
    "health.proto": "https://raw.githubusercontent.com/grpc/grpc-proto/refs/heads/master/grpc/health/v1/health.proto",
}


def update_protos() -> None:
    for filename, url in PROTOS.items():
        resp = httpx2.get(url, timeout=20)
        file = PROTOS_DIR / filename
        file.write_bytes(resp.content)
        proto_include = protoc._get_resource_file_name("grpc_tools", "_proto")  # noqa: SLF001
        args = [
            protoc.__file__,
            "-I",
            str(PROTOS_DIR),
            "-I",
            str(proto_include),
            "--python_out",
            str(PROTOS_DIR),
            "--pyi_out",
            str(PROTOS_DIR),
            "--grpc_python_out",
            str(PROTOS_DIR),
            str(file),
        ]
        protoc.main(args)
