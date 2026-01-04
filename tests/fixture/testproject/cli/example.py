import testproject.lib.cli as click
from testproject.core import di
from testproject.model import DeploymentEnvironment


@click.group("example")
def example(): ...


@example.command()
@di.inject
def hello(env: DeploymentEnvironment = di.Provide["env"]):
    click.echo(f"hello from {env.name}")
