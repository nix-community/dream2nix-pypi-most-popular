"""
Evaluates checks for x86_64-linux and aarch64-darwin and queries
a project on a buildbot instance for the last successful builds
of that project for build status and parts of the error logs
"""

import re
import json
import logging
from datetime import datetime
from pathlib import Path
import subprocess
import concurrent.futures
from jinja2 import Environment, FileSystemLoader
import requests


BUILDBOT_API_URI = "https://buildbot.nix-community.org/api/v2/"
BUILDBOT_PROJECT_NAME = "nix-community/dream2nix-pypi-most-popular"
POOL_SIZE = 20
re_name = re.compile(r"^.*#checks\.(x86_64-linux|aarch64-darwin)\.(.*)$")


logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger('report')
logger.setLevel(logging.DEBUG)
logging.getLogger("urllib3").setLevel(logging.INFO)


def api_get(path, json=True):
    with requests.get(f"{BUILDBOT_API_URI}{path}") as response:
        response.raise_for_status()
        if json:
            return response.json()
        else:
            return response.text


def get_ci_results_from_builder(builder):
    builder_name = builder.get('name')
    name_match = re_name.match(builder_name)
    if not name_match:
        return  # skip non-check jobs like the eval one
    system, package = name_match.groups()
    builder_id = builder.get("builderid")

    builds = api_get(f"/builders/{builder_id}/builds?order=-started_at&complete=true")["builds"]
    for build in builds:
        build_id = build.get("buildid")
        steps = api_get(f"builds/{build_id}/steps") \
            .get("steps", [])
        for step in steps:
            step_name = step['name']
            if step_name != "Build flake attr":
                continue
            step_id = step['stepid']

            logs = api_get(f"/steps/{step_id}/logs").get("logs", "[]")
            if len(logs) != 1:
                raise NotImplementedError("only 1 log per build implemented")
            log = logs[0]

            result = step["results"]
            if result == 0:
                status = "success"
            elif result == 2:
                status = "failure"
            elif result == 3:
                break
            else:
                raise NotImplementedError("unknown step results value")

            log_path = f"logs/{log["logid"]}/raw_inline"
            log_uri = f"{BUILDBOT_API_URI}{log_path}"
            log_tail = "\n".join(api_get(log_path, json=False).split("\n")[-100:])

            logging.debug(f"collected ci job info from {package} ({system}, {status}, {log_uri})")
            return package, system, {
                "status": status,
                "log_uri": log_uri,
                "started_at": step.get("started_at"),
                "complete_at": step.get("complete_at"),
                "log_tail": log_tail
            }


def get_ci_project_id(name):
    """project ids on buildbot.nix-community.org are unstable atm
    and i didn't get name filtering to work on first try, so
    we just filter the whole project list for now."""
    for project in api_get("projects").get("projects"):
        if project.get("name") == name:
            return project.get('projectid')


def get_ci_results():
    project_id = get_ci_project_id(BUILDBOT_PROJECT_NAME)
    builders = api_get(f"builders?projectid={project_id}") \
        .get("builders", [])

    ci_results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(get_ci_results_from_builder, builder) for builder in builders]
        for future in concurrent.futures.as_completed(futures):
            if result := future.result():
                package, system, info = result
                if package not in ci_results:
                    ci_results[package] = dict()
                ci_results[package][system] = info
    return ci_results


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


def get_checks(systems):
    logger.info(f"evaluating nix checks for: {systems}...")
    return {
        system: run_nix([
            "eval", f".#checks.{system}",
            "--apply", "builtins.mapAttrs (n: v: { storePath = v.out; source = v.config.mkDerivation.src.url;})"
        ])
        for system in systems
    }


def get_skipped_packages():
    logger.info("evaluating locking errors ...")
    return run_nix([
        "eval", ".#skippedPackages",
    ])


def cache_json(name, fun, *args):
    path = Path(f"{name}.json")
    if path.exists():
        logging.debug(f"found cached {path}, using that.")
        with open(path, "r") as f:
            results = json.load(f)
    else:
        logging.info(f"did NOT find cached {path}, creating it...")
        results = fun(*args)
        with open(path, "w") as f:
            json.dump(results, f)
    return results


if __name__ == '__main__':
    systems = ["x86_64-linux", "aarch64-darwin"]
    inputs = get_inputs()
    ci_results = cache_json("ci_results", get_ci_results)
    checks = cache_json("checks", get_checks, systems)
    skipped_packages = cache_json("skipped_packages", get_skipped_packages)

    results = []
    for package, check in checks["x86_64-linux"].items():
        if package not in ci_results:
            logging.error(f"Could NOT find ci results for {package}!")
            continue
        result = ci_results[package]
        result["name"] = package
        result["x86_64-linux"]["store_path"] = check["storePath"]
        result["from_wheel"] = check["source"].endswith(".whl")

        stati = [result.get(system, {}).get("status") == "success" for system in systems]
        if all(stati):
            result["status"] = "success"
        elif any(stati):
            result["status"] = "some"
        else:
            result["status"] = "failure"

        if package not in checks["aarch64-darwin"]:
            logging.warning(f"Could NOT evaluate aarch64-darwin store_path for {package}! Lock file out-dated?")
        else:
            result["aarch64-darwin"]["store_path"] = checks["aarch64-darwin"][package]["storePath"]
        results.append(result)

    stats_per_system = {
        system: dict(
            success=0,
            failure=0,
            skipped_packages=len(skipped_packages.keys())
        ) for system in systems
    }

    for result in results:
        for system in systems:
            status = result.get(system, {}).get("status", "failure")
            stats_per_system[system][status] += 1
    for system, stats in stats_per_system.items():
        stats["total"] = sum(stats.values())

    environment = Environment(loader=FileSystemLoader("."))
    environment.filters["parse_timestamp"] = datetime.fromtimestamp
    template = environment.get_template("report.html")

    print(template.render(
        results=sorted(results, key=lambda i: i["status"]),
        systems=systems,
        inputs=inputs,
        stats_per_system=stats_per_system,
        skipped_packages=skipped_packages,
        now=datetime.now()
    ))
