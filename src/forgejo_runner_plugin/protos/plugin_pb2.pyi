import datetime

from google.protobuf import duration_pb2 as _duration_pb2
from google.protobuf.internal import containers as _containers
from google.protobuf.internal import enum_type_wrapper as _enum_type_wrapper
from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from collections.abc import Iterable as _Iterable, Mapping as _Mapping
from typing import ClassVar as _ClassVar, Optional as _Optional, Union as _Union

DESCRIPTOR: _descriptor.FileDescriptor

class CapabilitiesRequest(_message.Message):
    __slots__ = ()
    def __init__(self) -> None: ...

class CapabilitiesResponse(_message.Message):
    __slots__ = ("name",)
    NAME_FIELD_NUMBER: _ClassVar[int]
    name: str
    def __init__(self, name: _Optional[str] = ...) -> None: ...

class ServiceContainer(_message.Message):
    __slots__ = ("name", "image", "env", "ports")
    class EnvEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: str
        def __init__(self, key: _Optional[str] = ..., value: _Optional[str] = ...) -> None: ...

    NAME_FIELD_NUMBER: _ClassVar[int]
    IMAGE_FIELD_NUMBER: _ClassVar[int]
    ENV_FIELD_NUMBER: _ClassVar[int]
    PORTS_FIELD_NUMBER: _ClassVar[int]
    name: str
    image: str
    env: _containers.ScalarMap[str, str]
    ports: _containers.RepeatedScalarFieldContainer[str]
    def __init__(
        self,
        name: _Optional[str] = ...,
        image: _Optional[str] = ...,
        env: _Optional[_Mapping[str, str]] = ...,
        ports: _Optional[_Iterable[str]] = ...,
    ) -> None: ...

class CreateRequest(_message.Message):
    __slots__ = (
        "image",
        "name",
        "cap_add",
        "cap_drop",
        "services",
        "backend_options",
        "label_arg",
        "environment_timeout",
    )
    class BackendOptionsEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: str
        def __init__(self, key: _Optional[str] = ..., value: _Optional[str] = ...) -> None: ...

    IMAGE_FIELD_NUMBER: _ClassVar[int]
    NAME_FIELD_NUMBER: _ClassVar[int]
    CAP_ADD_FIELD_NUMBER: _ClassVar[int]
    CAP_DROP_FIELD_NUMBER: _ClassVar[int]
    SERVICES_FIELD_NUMBER: _ClassVar[int]
    BACKEND_OPTIONS_FIELD_NUMBER: _ClassVar[int]
    LABEL_ARG_FIELD_NUMBER: _ClassVar[int]
    ENVIRONMENT_TIMEOUT_FIELD_NUMBER: _ClassVar[int]
    image: str
    name: str
    cap_add: _containers.RepeatedScalarFieldContainer[str]
    cap_drop: _containers.RepeatedScalarFieldContainer[str]
    services: _containers.RepeatedCompositeFieldContainer[ServiceContainer]
    backend_options: _containers.ScalarMap[str, str]
    label_arg: str
    environment_timeout: _duration_pb2.Duration
    def __init__(
        self,
        image: _Optional[str] = ...,
        name: _Optional[str] = ...,
        cap_add: _Optional[_Iterable[str]] = ...,
        cap_drop: _Optional[_Iterable[str]] = ...,
        services: _Optional[_Iterable[_Union[ServiceContainer, _Mapping]]] = ...,
        backend_options: _Optional[_Mapping[str, str]] = ...,
        label_arg: _Optional[str] = ...,
        environment_timeout: _Optional[_Union[datetime.timedelta, _duration_pb2.Duration, _Mapping]] = ...,
    ) -> None: ...

class CreateResponse(_message.Message):
    __slots__ = (
        "environment_id",
        "root_path",
        "act_path",
        "tool_cache_path",
        "temp_path",
        "path_variable_name",
        "default_path_variable",
        "path_separator",
        "environment_case_insensitive",
        "os",
        "arch",
    )
    ENVIRONMENT_ID_FIELD_NUMBER: _ClassVar[int]
    ROOT_PATH_FIELD_NUMBER: _ClassVar[int]
    ACT_PATH_FIELD_NUMBER: _ClassVar[int]
    TOOL_CACHE_PATH_FIELD_NUMBER: _ClassVar[int]
    TEMP_PATH_FIELD_NUMBER: _ClassVar[int]
    PATH_VARIABLE_NAME_FIELD_NUMBER: _ClassVar[int]
    DEFAULT_PATH_VARIABLE_FIELD_NUMBER: _ClassVar[int]
    PATH_SEPARATOR_FIELD_NUMBER: _ClassVar[int]
    ENVIRONMENT_CASE_INSENSITIVE_FIELD_NUMBER: _ClassVar[int]
    OS_FIELD_NUMBER: _ClassVar[int]
    ARCH_FIELD_NUMBER: _ClassVar[int]
    environment_id: str
    root_path: str
    act_path: str
    tool_cache_path: str
    temp_path: str
    path_variable_name: str
    default_path_variable: str
    path_separator: str
    environment_case_insensitive: bool
    os: str
    arch: str
    def __init__(
        self,
        environment_id: _Optional[str] = ...,
        root_path: _Optional[str] = ...,
        act_path: _Optional[str] = ...,
        tool_cache_path: _Optional[str] = ...,
        temp_path: _Optional[str] = ...,
        path_variable_name: _Optional[str] = ...,
        default_path_variable: _Optional[str] = ...,
        path_separator: _Optional[str] = ...,
        environment_case_insensitive: _Optional[bool] = ...,
        os: _Optional[str] = ...,
        arch: _Optional[str] = ...,
    ) -> None: ...

class StartRequest(_message.Message):
    __slots__ = ("environment_id",)
    ENVIRONMENT_ID_FIELD_NUMBER: _ClassVar[int]
    environment_id: str
    def __init__(self, environment_id: _Optional[str] = ...) -> None: ...

class StartOutput(_message.Message):
    __slots__ = ("data", "start_complete")
    DATA_FIELD_NUMBER: _ClassVar[int]
    START_COMPLETE_FIELD_NUMBER: _ClassVar[int]
    data: DataChunk
    start_complete: StartComplete
    def __init__(
        self,
        data: _Optional[_Union[DataChunk, _Mapping]] = ...,
        start_complete: _Optional[_Union[StartComplete, _Mapping]] = ...,
    ) -> None: ...

class StartComplete(_message.Message):
    __slots__ = ("image_env",)
    class ImageEnvEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: str
        def __init__(self, key: _Optional[str] = ..., value: _Optional[str] = ...) -> None: ...

    IMAGE_ENV_FIELD_NUMBER: _ClassVar[int]
    image_env: _containers.ScalarMap[str, str]
    def __init__(self, image_env: _Optional[_Mapping[str, str]] = ...) -> None: ...

class ExecRequest(_message.Message):
    __slots__ = ("environment_id", "command", "env", "user", "workdir")
    class EnvEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: str
        def __init__(self, key: _Optional[str] = ..., value: _Optional[str] = ...) -> None: ...

    ENVIRONMENT_ID_FIELD_NUMBER: _ClassVar[int]
    COMMAND_FIELD_NUMBER: _ClassVar[int]
    ENV_FIELD_NUMBER: _ClassVar[int]
    USER_FIELD_NUMBER: _ClassVar[int]
    WORKDIR_FIELD_NUMBER: _ClassVar[int]
    environment_id: str
    command: _containers.RepeatedScalarFieldContainer[str]
    env: _containers.ScalarMap[str, str]
    user: str
    workdir: str
    def __init__(
        self,
        environment_id: _Optional[str] = ...,
        command: _Optional[_Iterable[str]] = ...,
        env: _Optional[_Mapping[str, str]] = ...,
        user: _Optional[str] = ...,
        workdir: _Optional[str] = ...,
    ) -> None: ...

class ExecOutput(_message.Message):
    __slots__ = ("data", "exec_complete", "exec_failed")
    DATA_FIELD_NUMBER: _ClassVar[int]
    EXEC_COMPLETE_FIELD_NUMBER: _ClassVar[int]
    EXEC_FAILED_FIELD_NUMBER: _ClassVar[int]
    data: DataChunk
    exec_complete: ExecComplete
    exec_failed: ExecFailed
    def __init__(
        self,
        data: _Optional[_Union[DataChunk, _Mapping]] = ...,
        exec_complete: _Optional[_Union[ExecComplete, _Mapping]] = ...,
        exec_failed: _Optional[_Union[ExecFailed, _Mapping]] = ...,
    ) -> None: ...

class DataChunk(_message.Message):
    __slots__ = ("stream", "data")
    class Stream(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
        __slots__ = ()
        STDOUT: _ClassVar[DataChunk.Stream]
        STDERR: _ClassVar[DataChunk.Stream]

    STDOUT: DataChunk.Stream
    STDERR: DataChunk.Stream
    STREAM_FIELD_NUMBER: _ClassVar[int]
    DATA_FIELD_NUMBER: _ClassVar[int]
    stream: DataChunk.Stream
    data: bytes
    def __init__(
        self, stream: _Optional[_Union[DataChunk.Stream, str]] = ..., data: _Optional[bytes] = ...
    ) -> None: ...

class ExecComplete(_message.Message):
    __slots__ = ("exit_code",)
    EXIT_CODE_FIELD_NUMBER: _ClassVar[int]
    exit_code: int
    def __init__(self, exit_code: _Optional[int] = ...) -> None: ...

class ExecFailed(_message.Message):
    __slots__ = ("error_message",)
    ERROR_MESSAGE_FIELD_NUMBER: _ClassVar[int]
    error_message: str
    def __init__(self, error_message: _Optional[str] = ...) -> None: ...

class CopyInChunk(_message.Message):
    __slots__ = ("environment_id", "dest_path", "data")
    ENVIRONMENT_ID_FIELD_NUMBER: _ClassVar[int]
    DEST_PATH_FIELD_NUMBER: _ClassVar[int]
    DATA_FIELD_NUMBER: _ClassVar[int]
    environment_id: str
    dest_path: str
    data: bytes
    def __init__(
        self, environment_id: _Optional[str] = ..., dest_path: _Optional[str] = ..., data: _Optional[bytes] = ...
    ) -> None: ...

class CopyInResponse(_message.Message):
    __slots__ = ()
    def __init__(self) -> None: ...

class CopyOutRequest(_message.Message):
    __slots__ = ("environment_id", "src_path")
    ENVIRONMENT_ID_FIELD_NUMBER: _ClassVar[int]
    SRC_PATH_FIELD_NUMBER: _ClassVar[int]
    environment_id: str
    src_path: str
    def __init__(self, environment_id: _Optional[str] = ..., src_path: _Optional[str] = ...) -> None: ...

class CopyOutChunk(_message.Message):
    __slots__ = ("data",)
    DATA_FIELD_NUMBER: _ClassVar[int]
    data: bytes
    def __init__(self, data: _Optional[bytes] = ...) -> None: ...

class RemoveRequest(_message.Message):
    __slots__ = ("environment_id",)
    ENVIRONMENT_ID_FIELD_NUMBER: _ClassVar[int]
    environment_id: str
    def __init__(self, environment_id: _Optional[str] = ...) -> None: ...

class RemoveResponse(_message.Message):
    __slots__ = ()
    def __init__(self) -> None: ...
