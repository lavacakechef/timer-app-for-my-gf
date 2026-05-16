#!/usr/bin/env python3
"""Codex Stop hook for CozyTime.

This is a guardrail, not a security boundary. It runs fast local checks after a
turn if relevant files changed, then asks Codex to continue when the checks fail.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


def emit(payload: dict) -> None:
    print(json.dumps(payload))


def run(cmd: list[str], cwd: Path, timeout: int = 120) -> tuple[int, str]:
    completed = subprocess.run(
        cmd,
        cwd=str(cwd),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
    )
    return completed.returncode, completed.stdout[-6000:]


def git_root(cwd: Path) -> Path:
    code, out = run(["git", "rev-parse", "--show-toplevel"], cwd, timeout=15)
    if code != 0:
        return cwd
    return Path(out.strip())


def changed_files(root: Path) -> list[str]:
    code, out = run(["git", "status", "--porcelain"], root, timeout=15)
    if code != 0:
        return []
    files: list[str] = []
    for line in out.splitlines():
        if len(line) < 4:
            continue
        path = line[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        files.append(path)
    return files


def is_swift_or_project(path: str) -> bool:
    return (
        path.endswith(".swift")
        or path in {"Package.swift", "project.yml"}
        or path.startswith("XcodeSupport/")
        or path.startswith("XcodeTests/")
        or path.startswith("Tests/")
    )


def is_ui_surface(path: str) -> bool:
    return (
        path.startswith("Sources/CozyTime/")
        and path.endswith(".swift")
        and (
            "View" in Path(path).name
            or Path(path).name
            in {
                "CozyTimeApp.swift",
                "DesignSystem.swift",
                "Commands.swift",
                "StatusBarController.swift",
            }
        )
    )


def main() -> int:
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError:
        hook_input = {}

    root = git_root(Path(hook_input.get("cwd") or os.getcwd()))
    files = changed_files(root)
    if not files:
        emit({"continue": True})
        return 0

    checks: list[tuple[str, list[str], int]] = []
    if any(is_ui_surface(path) for path in files) and (root / "scripts/lint_design.sh").exists():
        checks.append(("design lint", ["scripts/lint_design.sh"], 90))

    if any(is_swift_or_project(path) for path in files):
        checks.append(("swift build", ["swift", "build"], 120))

    if any(path.startswith(("Sources/CozyCore/", "Tests/")) or path == "Package.swift" for path in files):
        checks.append(("swift test", ["swift", "test"], 180))

    failures: list[str] = []
    for label, cmd, timeout in checks:
        code, out = run(cmd, root, timeout=timeout)
        if code != 0:
            failures.append(f"{label} failed with exit {code}\n{out}")

    if failures:
        emit(
            {
                "decision": "block",
                "reason": "CozyTime quality gate failed. Fix these before stopping:\n\n"
                + "\n\n".join(failures),
            }
        )
        return 0

    emit({"continue": True})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
