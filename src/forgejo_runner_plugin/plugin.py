#!/usr/bin/env python3

import logging
import shutil
import tarfile
from collections.abc import Iterator
from pathlib import Path, PurePath
from typing import override

import grpc

from .generator import GeneratorWrapper
from .protos import health_pb2, health_pb2_grpc, plugin_pb2, plugin_pb2_grpc
from .runner import ForgejoActionRunner


def chunk(data: bytes, *, stderr: bool = False) -> plugin_pb2.DataChunk:
    stream = plugin_pb2.DataChunk.Stream.STDERR if stderr else plugin_pb2.DataChunk.Stream.STDOUT
    return plugin_pb2.DataChunk(data=data, stream=stream)


class Health(health_pb2_grpc.HealthServicer):
    @override
    def Check(
        self, request: health_pb2.HealthCheckRequest, context: grpc.ServicerContext
    ) -> health_pb2.HealthCheckResponse:
        logging.debug("health_pb2.Health Check requested")
        return health_pb2.HealthCheckResponse(status=health_pb2.HealthCheckResponse.ServingStatus.SERVING)

    # @override
    # def List(
    #     self, request: health_pb2.HealthListRequest, context: grpc.ServicerContext
    # ) -> health_pb2.HealthListResponse:
    #     logging.debug("health_pb2.Health List requested")
    #     return health_pb2.HealthListResponse()

    # @override
    # def Watch(
    #     self, request: health_pb2.HealthCheckRequest, context: grpc.ServicerContext
    # ) -> Iterator[health_pb2.HealthCheckResponse]:
    #     logging.debug("health_pb2.Health Watch requested")
    #     yield self.Check(request, context)


class ForgejoPlugin(plugin_pb2_grpc.BackendPluginServicer):
    def __init__(self, name: str, tempdir: Path, runner_class: type[ForgejoActionRunner]) -> None:
        self.name = name
        self.tempdir = tempdir
        self.runner_class = runner_class
        self.environments: dict[str, ForgejoActionRunner] = {}
        super().__init__()

    def _ensure_runner(self, environment_id: str) -> ForgejoActionRunner:
        if environment_id not in self.environments:
            msg = f"Could not find environment '{environment_id}'"
            raise RuntimeError(msg)
        return self.environments[environment_id]

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
        runner = self.runner_class.create(
            request.name,
            request.image,
            request.label_arg,
            (list(request.cap_add), list(request.cap_drop)),
            dict(request.backend_options),
            request.environment_timeout.seconds,
            self.tempdir / env_id,
        )
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
        start_log = GeneratorWrapper(runner.start())
        for line in start_log:
            yield plugin_pb2.StartOutput(data=chunk(line))
        yield plugin_pb2.StartOutput(start_complete=plugin_pb2.StartComplete(image_env={}))

    @override
    def CopyIn(
        self, request_iterator: Iterator[plugin_pb2.CopyInChunk], context: grpc.ServicerContext
    ) -> plugin_pb2.CopyInResponse:
        logging.debug("Plugin CopyIn called")
        # First iterator describes the environment
        request = next(request_iterator)
        target = PurePath(request.dest_path)
        runner = self._ensure_runner(request.environment_id)
        temp_target = runner.workdir / "push" / target.name
        temp_tar_file = runner.workdir / "push" / f"{target.name}.tar"
        temp_target.parent.mkdir(exist_ok=True)

        with temp_tar_file.open("wb") as tar:
            for request in request_iterator:
                tar.write(request.data)

        # FIXME: extract in container?
        with tarfile.open(temp_tar_file, "r") as tar:
            tar.extractall(temp_target, filter="data")
        temp_tar_file.unlink()

        runner.push(temp_target, PurePath(target))
        if temp_target.is_dir():
            shutil.rmtree(temp_target)
        else:
            temp_target.unlink()

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

        try:
            exec_log = GeneratorWrapper(
                runner.exec(
                    list(request.command),
                    user=request.user,
                    workdir=PurePath(request.workdir),
                    env=dict(request.env),
                )
            )
        except Exception as err:  # noqa: BLE001
            yield plugin_pb2.ExecOutput(exec_failed=plugin_pb2.ExecFailed(error_message=str(err)))
            return

        for stdout, stderr in exec_log:
            if stdout:
                yield plugin_pb2.ExecOutput(data=chunk(stdout, stderr=False))
            if stderr:
                yield plugin_pb2.ExecOutput(data=chunk(stderr, stderr=True))

        returncode = exec_log.returned
        complete = plugin_pb2.ExecComplete(exit_code=returncode)
        yield plugin_pb2.ExecOutput(exec_complete=complete)


def init_grpc_server(server: grpc.Server, plugin: ForgejoPlugin) -> grpc.Server:
    health_pb2_grpc.add_HealthServicer_to_server(Health(), server)
    plugin_pb2_grpc.add_BackendPluginServicer_to_server(plugin, server)
    return server
