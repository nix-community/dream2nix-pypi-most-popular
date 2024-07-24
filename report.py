import re
import json
import pickle
import logging
import multiprocessing
import subprocess
from dataclasses import dataclass
from typing import Callable, Sequence, Tuple, TypeVar
from jinja2 import Environment, FileSystemLoader

POOL_SIZE = 20

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger('report')
logger.setLevel(logging.DEBUG)


@dataclass
class Dependency:
    name: str
    drv: str


@dataclass
class Result:
    @property
    def state(self):
        return "success" if isinstance(self, Success) else "failure"

    @property
    def icon(self):
        return "✅" if isinstance(self, Success) else "❌"


@dataclass
class Success(Result):
    name: str
    output: str


@dataclass
class Failure(Result):
    name: str
    log: str


T = TypeVar("T")


def partition_list(items: Sequence[T], predicate: Callable[[T], bool]):
    yes, no = [], []
    for i in items:
        (yes if predicate(i) else no).append(i)
    return [yes, no]


def run_nix(args, with_json=True):
    args = ["nix", *args]
    if with_json:
        args.append('--json')
    proc = subprocess.run(
        args,
        check=True,
        capture_output=True,
    )
    if with_json:
        return json.loads(proc.stdout)
    else:
        return proc.stdout.strip()


def get_current_system():
    return run_nix([
        'eval', '--impure', '--expr', 'builtins.currentSystem'
    ])


def get_inputs():
    metadata = run_nix([
        'flake', 'metadata'
    ])

    def _github_lock_to_url(lock):
        assert lock.get("type") == "github"
        return f'https://github.com/{lock["owner"]}/{lock["repo"]}/tree/{lock["rev"]}'

    return {
        name: _github_lock_to_url(node.get("locked", {}))
        for name, node in metadata.get('locks', {}).get('nodes', {}).items()
        if name in ['nixpkgs', 'dream2nix']
    }


def get_dependency_drv_paths(system):
    logger.info("evaluating nix drvPaths...")
    args = [
        'nix-eval-jobs',
        "--flake",
        f".#packages.{system}",
    ]

    with subprocess.Popen(args, stdout=subprocess.PIPE, encoding="utf-8") as proc:
        for line in proc.stdout:
            data = json.loads(line)
            yield (data['attr'], data['drvPath'])


def process_package(arg: Tuple[int, Dependency]) -> Success | Failure:
    count, dependency = arg
    logger.debug(f"building {dependency.name} (#{count})")

    proc = subprocess.run(
        ["nix", "build", "--print-build-logs", "--print-out-paths", "--no-link", f"{dependency.drv}^out"],
        capture_output=True,
        encoding="utf-8"
    )

    if proc.returncode != 0:
        error = proc.stderr.strip()
        logger.error(f"build of {dependency.name} failed")
        return Failure(dependency.name, error)

    logger.info(f"build of {dependency.name} succeeded")
    output = proc.stdout.strip()
    return Success(dependency.name, output)


if __name__ == '__main__':
    # system = get_current_system()
    # inputs = get_inputs()
    # dependencies = get_dependency_drv_paths(system)
    # pool = multiprocessing.Pool(POOL_SIZE)
    # items = pool.map(process_package, enumerate([Dependency(name, drv) for name, drv in dependencies]))
    # successes, failures = partition_list(items, lambda r: r.state == "success")

    # #module_not_found_error = re.compile(r"^       > ModuleNotFoundError: No module named '(.*)'$", re.M)
    # missing_dependency_error = re.compile(r"^\s*> ERROR Missing dependencies:.*$", re.M)
    # with open("build-requirements.txt", "w") as f:
    #     for failure in failures:
    #         m = missing_dependency_error.search(failure.log)
    #         if m:
    #             f.write(f'{failure.name} = {failure.log[m.end():]}\n')

    # with open("./report_fixtures/successes.pickle", "wb") as f:
    #     pickle.dump(successes, f)
    # with open("./report_fixtures/failures.pickle", "wb") as f:
    #     pickle.dump(failures, f)
    # with open("./report_fixtures/system.pickle", "wb") as f:
    #     pickle.dump(system, f)
    # with open("./report_fixtures/inputs.pickle", "wb") as f:
    #     pickle.dump(inputs, f)

    environment = Environment(loader=FileSystemLoader("."))
    template = environment.get_template("report.html")

    with open("./report_fixtures/successes.pickle", "rb") as f:
        successes = pickle.load(f)
    with open("./report_fixtures/failures.pickle", "rb") as f:
        failures = pickle.load(f)
    with open("./report_fixtures/system.pickle", "rb") as f:
        system = pickle.load(f)
    with open("./report_fixtures/inputs.pickle", "rb") as f:
        inputs = pickle.load(f)

    with open("index.html", "w") as f:
        f.write(template.render(
            successes=successes,
            failures=failures,
            system=system,
            inputs=inputs
        ))
