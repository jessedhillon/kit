from fastapi import APIRouter, Depends, Query

from testproject.core import di
from testproject.model import DeploymentEnvironment

from ..view import HelloView

router = APIRouter(prefix="/api")


@router.get("/", operation_id="index")
@di.inject
def index(
    env: DeploymentEnvironment = Depends(di.Provide["env"]),
) -> HelloView:
    return HelloView(env=env)
