import os
import typing as t
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from testproject.core import BootConfiguration, di, TestContainer
from testproject.core.config import ExampleWebSettings
from testproject.model import DeploymentEnvironment

from .route import router


@di.inject
def _create_app(
    config: ExampleWebSettings = di.Provide["config.web.example", di.as_(ExampleWebSettings)],
    env: DeploymentEnvironment = di.Provide["env"],
    root_path: Path = di.Provide["root"],
) -> FastAPI:
    app = FastAPI(title="Example")
    if env is DeploymentEnvironment.Local:
        assert config.frontend is not None
        app.add_middleware(
            CORSMiddleware,
            allow_origins=[
                f"http://{config.frontend.host}:{config.frontend.port}",
                f"http://localhost:{config.frontend.port}"
            ],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
    app.include_router(router)
    return app


def create_app() -> FastAPI:
    boot_vars = os.getenv("__Test_BOOT")
    if boot_vars:
        boot_cf = BootConfiguration.model_validate_json(boot_vars)
        ct = TestContainer()
        TestContainer.boot(ct, **dict(boot_cf))
        ct.wire(modules=["testproject.web.example.main"])
        return _create_app(
            config=ExampleWebSettings(**ct.config.web.example()), env=boot_cf.env, root_path=t.cast(Path, ct.root())
        )
    return _create_app()
