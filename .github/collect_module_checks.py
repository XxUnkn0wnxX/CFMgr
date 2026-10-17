"""Read-only, exact-candidate collection of the three independent module runs."""

from __future__ import annotations

import json
import os
import re
import time
import urllib.request
from pathlib import Path

OWNERS = ("backup", "manager", "status")
API_VERSION = "2026-03-10"
POLL_SECONDS = 15
LIMIT_SECONDS = 900


class CollectionError(Exception):
    """Missing, mismatched or nonpassing required evidence."""


def require(condition, message):
    if not condition:
        raise CollectionError(message)


def positive(value):
    return type(value) is int and value > 0


def workflow_path(value, owner):
    path = f".github/workflows/{owner}-checks.yml"
    return isinstance(value, str) and (
        value == path or (value.startswith(path + "@") and len(value) > len(path) + 1)
    )


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        raise CollectionError("Unexpected API redirect")


class API:
    def __init__(self, repository, token, deadline):
        self.base = f"https://api.github.com/repos/{repository}"
        self.token = token
        self.deadline = deadline

    def get(self, path):
        remaining = self.deadline - time.monotonic()
        require(remaining > 0, "Module collection deadline expired")
        request = urllib.request.Request(
            self.base + path,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": API_VERSION,
            },
        )
        with urllib.request.build_opener(NoRedirect).open(
            request, timeout=min(20, remaining)
        ) as response:
            data = response.read(4 * 1024 * 1024 + 1)
        require(len(data) <= 4 * 1024 * 1024, "API response exceeds bound")
        return json.loads(data)


def title(owner, candidate, *, parent=None, pr=None):
    correlation = f"pr={pr}" if pr is not None else f"parent={parent}"
    return f"{owner.title()} Checks {correlation} sha={candidate}"


def validate_run(run, owner, repository, candidate, workflow_id, expected_title, event):
    require(positive(run.get("id")), "Invalid module run ID")
    require(
        run.get("repository", {}).get("full_name") == repository, "Wrong run repository"
    )
    require(run.get("workflow_id") == workflow_id, "Wrong module workflow ID")
    require(workflow_path(run.get("path"), owner), "Wrong workflow path")
    require(run.get("event") == event, "Wrong module event")
    require(run.get("display_title") == expected_title, "Wrong module candidate title")
    require(positive(run.get("run_attempt")), "Invalid run attempt")
    if event == "workflow_dispatch":
        require(run.get("head_sha") == candidate, "Wrong dispatch candidate SHA")


def discover_pr(api, owner, expected_title):
    matches = []
    for page in range(1, 4):
        result = api.get(
            f"/actions/workflows/{owner}-checks.yml/runs?event=pull_request&per_page=100&page={page}"
        )
        runs = result.get("workflow_runs", [])
        require(isinstance(runs, list) and len(runs) <= 100, "Invalid PR runs page")
        matches.extend(
            run for run in runs if run.get("display_title") == expected_title
        )
        if len(runs) < 100:
            break
    if not matches:
        return None
    require(all(positive(run.get("id")) for run in matches), "Invalid PR run ID")
    return max(matches, key=lambda run: run["id"])


def validate_jobs(result, owner, run_id):
    jobs = result.get("jobs", [])
    require(
        result.get("total_count") == 2 and len(jobs) == 2,
        "Expected exactly two platform jobs",
    )
    expected = {
        f"{owner.title()} Checks ({platform})" for platform in ("host", "busybox")
    }
    require(
        {job.get("name") for job in jobs} == expected,
        "Wrong or duplicate platform jobs",
    )
    required = (
        "Validate exact candidate",
        "Check out source",
        "Verify checked out candidate",
        f"Run complete {owner} checks",
    )
    for job in jobs:
        require(job.get("run_id") == run_id, "Wrong job run ID")
        require(
            job.get("status") == "completed" and job.get("conclusion") == "success",
            "Nonpassing platform job",
        )
        steps = job.get("steps", [])
        numbers = []
        for name in required:
            selected = [step for step in steps if step.get("name") == name]
            require(len(selected) == 1, f"Missing/duplicate required step: {name}")
            step = selected[0]
            require(
                step.get("status") == "completed"
                and step.get("conclusion") == "success",
                f"Nonpassing required step: {name}",
            )
            require(positive(step.get("number")), "Invalid step number")
            numbers.append(step["number"])
        require(
            numbers == sorted(set(numbers)),
            "Candidate validation/checkout/test order changed",
        )


def collect(
    api,
    repository,
    candidate,
    event,
    parent,
    pr,
    runs,
    *,
    clock=time.monotonic,
    sleep=time.sleep,
):
    require(
        bool(re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository)),
        "Invalid repository",
    )
    require(
        bool(re.fullmatch(r"[0-9a-f]{40}", candidate)), "Invalid full candidate SHA"
    )
    require(
        event in {"push", "workflow_dispatch", "pull_request"},
        "Unsupported parent event",
    )
    is_pr = event == "pull_request"
    require(str(pr if is_pr else parent).isdigit(), "Invalid parent/PR correlation")
    require(
        (not runs) if is_pr else set(runs) == set(OWNERS),
        "Missing or unexpected dispatch mapping",
    )
    workflows = {}
    for owner in OWNERS:
        workflow = api.get(f"/actions/workflows/{owner}-checks.yml")
        require(
            positive(workflow.get("id"))
            and workflow.get("path") == f".github/workflows/{owner}-checks.yml",
            "Invalid fixed workflow identity",
        )
        workflows[owner] = workflow["id"]
        if not is_pr:
            require(
                set(runs[owner]) == {"id", "attempt"}
                and all(positive(value) for value in runs[owner].values()),
                "Invalid dispatch mapping",
            )
    deadline = clock() + LIMIT_SECONDS
    for _ in range(61):
        require(clock() < deadline, "Module collection exceeded 15 minutes")
        complete = {}
        for owner in OWNERS:
            expected_title = title(
                owner, candidate, parent=parent, pr=pr if is_pr else None
            )
            selected = discover_pr(api, owner, expected_title) if is_pr else runs[owner]
            if selected is None:
                continue
            run_id = selected["id"]
            run = api.get(f"/actions/runs/{run_id}")
            validate_run(
                run,
                owner,
                repository,
                candidate,
                workflows[owner],
                expected_title,
                "pull_request" if is_pr else "workflow_dispatch",
            )
            require(run["id"] == run_id, "Wrong requested run ID")
            attempt = run["run_attempt"]
            if not is_pr:
                require(
                    attempt <= selected["attempt"], "Unexpected newer dispatch attempt"
                )
                if attempt < selected["attempt"]:
                    continue  # Rerun request not visible yet; never accept its old success.
            if run.get("status") != "completed":
                require(
                    run.get("status")
                    in {"queued", "in_progress", "waiting", "pending", "requested"},
                    "Unknown module status",
                )
                continue
            require(run.get("conclusion") == "success", f"{owner} did not succeed")
            jobs = api.get(
                f"/actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100"
            )
            validate_jobs(jobs, owner, run_id)
            after = api.get(f"/actions/runs/{run_id}")
            validate_run(
                after,
                owner,
                repository,
                candidate,
                workflows[owner],
                expected_title,
                "pull_request" if is_pr else "workflow_dispatch",
            )
            require(
                (
                    after.get("id"),
                    after.get("run_attempt"),
                    after.get("status"),
                    after.get("conclusion"),
                )
                == (run_id, attempt, "completed", "success"),
                "Module metadata/attempt changed during collection",
            )
            complete[owner] = run_id
        if len(complete) == len(OWNERS):
            return complete
        remaining = deadline - clock()
        require(remaining > 0, "Module collection exceeded 15 minutes")
        sleep(min(POLL_SECONDS, remaining))
    raise CollectionError("Module collection polling bound exhausted")


def main():
    deadline = time.monotonic() + LIMIT_SECONDS
    repository = os.environ["GITHUB_REPOSITORY"]
    api = API(repository, os.environ["GH_TOKEN"], deadline)
    result = collect(
        api,
        repository,
        os.environ["GITHUB_SHA"],
        os.environ["GITHUB_EVENT_NAME"],
        os.environ["GITHUB_RUN_ID"],
        os.environ.get("CFMGR_PR_NUMBER"),
        json.loads(os.environ.get("CFMGR_MODULE_RUNS") or "{}"),
    )
    with Path(os.environ["GITHUB_STEP_SUMMARY"]).open("a") as summary:
        summary.writelines(
            f"- [{owner.title()} Checks](https://github.com/{repository}/actions/runs/{run_id}): passed\n"
            for owner, run_id in result.items()
        )


if __name__ == "__main__":
    main()
