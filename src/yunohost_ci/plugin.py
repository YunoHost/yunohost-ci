#!/usr/bin/env python3

import logging
import shutil
import tarfile
from collections.abc import Iterator
from concurrent import futures
from pathlib import Path, PurePath
from typing import override

import grpc

from .protos import health_pb2, health_pb2_grpc, plugin_pb2, plugin_pb2_grpc
from .runner import YunohostCIRunner


class Generator:
    def __init__(self, gen):
        self.gen = gen

    def __iter__(self):
        self.value = yield from self.gen
        return self.value


class Health(health_pb2_grpc.HealthServicer):
    @override
    def Check(
        self, request: health_pb2.HealthCheckRequest, context: grpc.ServicerContext
    ) -> health_pb2.HealthCheckResponse:
        logging.debug("health_pb2.Health Check requested")
        return health_pb2.HealthCheckResponse(status=health_pb2.HealthCheckResponse.ServingStatus.SERVING)

    @override
    def List(
        self, request: health_pb2.HealthListRequest, context: grpc.ServicerContext
    ) -> health_pb2.HealthListResponse:
        logging.debug("health_pb2.Health List requested")
        return health_pb2.HealthListResponse()

    # @override
    # def Watch(
    #     self, request: health_pb2.HealthCheckRequest, context: grpc.ServicerContext
    # ) -> health_pb2.HealthCheckResponse:
    #     logging.debug("health_pb2.Health Watch requested")
    #     pass


class YunohostPlugin(plugin_pb2_grpc.BackendPluginServicer):
    name = "yunohost-ci"

    def __init__(self, tempdir: Path) -> None:
        self.tempdir = tempdir
        self.environments: dict[str, YunohostCIRunner] = {}
        super().__init__()

    def _ensure_runner(self, environment_id: str) -> YunohostCIRunner:
        if environment_id not in self.environments:
            msg = f"Could not find environment '{environment_id}'"
            raise RuntimeError(msg)
        return self.environments[environment_id]

    def _sendline(self, line: str, *, stderr: bool = False) -> plugin_pb2.DataChunk:
        stream = plugin_pb2.DataChunk.Stream.STDERR if stderr else plugin_pb2.DataChunk.Stream.STDOUT
        return plugin_pb2.DataChunk(data=line.encode(), stream=stream)

    @override
    def Capabilities(
        self, request: plugin_pb2.CapabilitiesRequest, context: grpc.ServicerContext
    ) -> plugin_pb2.CapabilitiesResponse:
        logging.debug("Plugin Capabilities called")
        return plugin_pb2.CapabilitiesResponse(name=self.name)

    @override
    def Create(self, request: plugin_pb2.CreateRequest, context: grpc.ServicerContext) -> plugin_pb2.CreateResponse:
        logging.debug("Plugin Create called")
        print(request)
        env_id = f"{request.image}-{request.name}"
        runner = YunohostCIRunner(self.tempdir / f"{env_id}.workdir")
        self.environments[env_id] = runner

        return plugin_pb2.CreateResponse(
            environment_id=env_id,
            root_path=str(runner.root_path),
            act_path=str(runner.act_path),
            tool_cache_path=str(runner.tool_cache_path),
            temp_path=str(runner.temp_path),
            environment_case_insensitive=True,
            os="Linux",
            arch="x64",
        )

    @override
    def Remove(self, request: plugin_pb2.RemoveRequest, context: grpc.ServicerContext) -> plugin_pb2.RemoveResponse:
        logging.debug("Plugin Remove called")
        self._ensure_runner(request.environment_id)
        self.environments.pop(request.environment_id).cleanup()
        return plugin_pb2.RemoveResponse()

    @override
    def Start(
        self, request: plugin_pb2.StartRequest, context: grpc.ServicerContext
    ) -> Iterator[plugin_pb2.StartOutput]:
        logging.debug("Plugin Start called")
        # yield plugin_pb2.StartOutput(data=plugin_pb2.DataChunk(b"toto this is a log line"))

        runner = self._ensure_runner(request.environment_id)
        start_log = Generator(runner.start())
        for line in start_log:
            yield plugin_pb2.StartOutput(data=self._sendline(line))
        yield plugin_pb2.StartOutput(start_complete=plugin_pb2.StartComplete(image_env={}))

    @override
    def CopyIn(
        self, request_iterator: Iterator[plugin_pb2.CopyInChunk], context: grpc.ServicerContext
    ) -> plugin_pb2.CopyInResponse:
        logging.debug("Plugin CopyIn called")
        # First iterator describes the environment
        request = next(request_iterator)
        env_id = request.environment_id
        path = request.dest_path
        runner = self._ensure_runner(request.environment_id)
        temp_dest_dir = self.tempdir / f"{env_id}.push"
        temp_tar_file = self.tempdir / f"{env_id}.push.tar"

        with temp_tar_file.open("wb") as tar:
            for request in request_iterator:
                tar.write(request.data)

        # FIXME: extract in container?
        with tarfile.open(temp_tar_file, "r") as tar:
            tar.extractall(temp_dest_dir, filter="data")
        temp_tar_file.unlink()

        runner.push(temp_dest_dir, PurePath(path))
        shutil.rmtree(temp_dest_dir)

        return plugin_pb2.CopyInResponse()

    @override
    def CopyOut(
        self, request: plugin_pb2.CopyOutRequest, context: grpc.ServicerContext
    ) -> Iterator[plugin_pb2.CopyOutChunk]:
        logging.debug("Plugin CopyOut called")
        env_id = request.environment_id
        path = request.src_path
        runner = self._ensure_runner(request.environment_id)
        temp_dest_dir = self.tempdir / f"{env_id}.pull"
        temp_tar_file = self.tempdir / f"{env_id}.pull.tar"

        temp_dest_dir.mkdir(exist_ok=True)
        runner.pull(PurePath(path), temp_dest_dir)

        with tarfile.open(temp_tar_file, "w") as tar:
            tar.add(temp_dest_dir, arcname=temp_dest_dir.name)
        shutil.rmtree(temp_dest_dir)

        with temp_tar_file.open("rb") as tar:
            while chunk := tar.read(4096):
                yield plugin_pb2.CopyOutChunk(data=chunk)
        temp_tar_file.unlink()

    @override
    def Exec(self, request: plugin_pb2.ExecRequest, context: grpc.ServicerContext) -> Iterator[plugin_pb2.ExecOutput]:
        logging.debug("Plugin Exec called")
        runner = self._ensure_runner(request.environment_id)

        exec_log = Generator(
            runner.exec(
                list(request.command),
                user=request.user,
                workdir=PurePath(request.workdir),
                env=dict(request.env),
            )
        )

        for line in exec_log:
            yield plugin_pb2.ExecOutput(data=self._sendline(line, stderr=False))

        returncode = exec_log.value
        complete = plugin_pb2.ExecComplete(exit_code=returncode)
        # failed=plugin_pb2.ExecFailed(error_message=f"Failed with code {returncode}") if returncode else None
        yield plugin_pb2.ExecOutput(exec_complete=complete)


def init_server(tempdir: Path) -> grpc.Server:
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    health_pb2_grpc.add_HealthServicer_to_server(Health(), server)
    plugin_pb2_grpc.add_BackendPluginServicer_to_server(YunohostPlugin(tempdir), server)

    return server
