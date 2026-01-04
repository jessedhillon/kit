import pydantic as p

from testproject.model import BaseModel, DeploymentEnvironment


class HelloView(BaseModel):
    env: DeploymentEnvironment

    @p.computed_field
    def message(self) -> str:
        return f"Hello from {self.env.name}"
