#!/usr/bin/env python3
"""Bump every package to the next shared version and prepend changelogs.

Commit subjects since the last release become the changelog bullets. The bump
level is conventional commits unless --bump is patch, minor, or major:

  breaking change -> major
  feat            -> minor
  anything else   -> patch

The last release is the git tag 0.1.2 or v0.1.2 when one exists. Otherwise it
is the commit that set `version:` in the umbrella pubspec.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UMBRELLA = ROOT / "packages" / "banxa_payments_flutter" / "pubspec.yaml"

VERSION_FILES = [
    ROOT / "packages" / "banxa_payments_flutter" / "pubspec.yaml",
    ROOT / "packages" / "banxa_payments_flutter_ios" / "pubspec.yaml",
    ROOT / "packages" / "banxa_payments_flutter_android" / "pubspec.yaml",
    ROOT / "packages" / "banxa_payments_flutter_platform_interface" / "pubspec.yaml",
    ROOT / "packages" / "banxa_payments_flutter_ios" / "ios" / "banxa_payments_flutter_ios.podspec",
    ROOT / "example" / "pubspec.yaml",
    ROOT / "README.md",
    ROOT / "packages" / "banxa_payments_flutter" / "README.md",
    ROOT / "packages" / "banxa_payments_flutter_ios" / "README.md",
    ROOT / "packages" / "banxa_payments_flutter_android" / "README.md",
    ROOT / "packages" / "banxa_payments_flutter_platform_interface" / "README.md",
]

CHANGELOGS = [
    ROOT / "CHANGELOG.md",
    ROOT / "packages" / "banxa_payments_flutter" / "CHANGELOG.md",
    ROOT / "packages" / "banxa_payments_flutter_ios" / "CHANGELOG.md",
    ROOT / "packages" / "banxa_payments_flutter_android" / "CHANGELOG.md",
    ROOT / "packages" / "banxa_payments_flutter_platform_interface" / "CHANGELOG.md",
]


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def current_version() -> str:
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\s*$", UMBRELLA.read_text(), re.M)
    if not match:
        sys.exit(f"no version in {UMBRELLA}")
    return match.group(1)


def bump_version(version: str, level: str) -> str:
    major, minor, patch = (int(part) for part in version.split("."))
    if level == "major":
        return f"{major + 1}.0.0"
    if level == "minor":
        return f"{major}.{minor + 1}.0"
    if level == "patch":
        return f"{major}.{minor}.{patch + 1}"
    sys.exit(f"unknown bump level: {level}")


def release_revision(version: str) -> str | None:
    tags = set(git("tag", "--list").splitlines())
    for tag in (version, f"v{version}"):
        if tag in tags:
            return tag
    try:
        return git(
            "log",
            "-1",
            "--format=%H",
            "-S",
            f"version: {version}",
            "--",
            "packages/banxa_payments_flutter/pubspec.yaml",
        )
    except subprocess.CalledProcessError:
        return None


def commit_messages(revision: str | None) -> list[str]:
    revision_range = f"{revision}..HEAD" if revision else "HEAD"
    raw = git("log", revision_range, "--format=%s%x1e%b%x1f")
    messages: list[str] = []
    for entry in raw.split("\x1f"):
        entry = entry.strip()
        if not entry:
            continue
        subject, _, body = entry.partition("\x1e")
        subject = subject.strip()
        if (
            not subject
            or subject.startswith("chore: bump version")
            or subject.startswith("Merge ")
        ):
            continue
        messages.append(f"{subject}\n{body}".strip())
    return messages


def bump_level(messages: list[str], requested: str) -> str:
    if requested != "auto":
        return requested
    level = "patch"
    for message in messages:
        if re.search(r"(?m)^BREAKING CHANGE\b", message) or re.match(
            r"^\w+(\([^)]+\))?!:", message
        ):
            return "major"
        if re.match(r"^feat(\([^)]+\))?:", message):
            level = "minor"
    return level


def replace_current(text: str, current: str, new: str) -> str:
    return text.replace(current, new)


def prepend_changelog(path: Path, version: str, subjects: list[str]) -> None:
    bullets = "\n".join(f"- {subject}" for subject in subjects)
    section = f"## {version}\n\n{bullets}\n\n"
    text = path.read_text()
    marker = "# Changelog\n\n"
    if not text.startswith(marker):
        sys.exit(f"{path} does not start with {marker!r}")
    path.write_text(marker + section + text[len(marker) :])


def write_output(version: str, level: str) -> None:
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        return
    with open(output, "a", encoding="utf-8") as handle:
        handle.write(f"version={version}\n")
        handle.write(f"level={level}\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--bump",
        choices=("auto", "patch", "minor", "major"),
        default="auto",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the next version and changelog bullets without writing files.",
    )
    args = parser.parse_args()

    current = current_version()
    messages = commit_messages(release_revision(current))
    if not messages:
        sys.exit(f"no commits since {current}; nothing to release")

    level = bump_level(messages, args.bump)
    new = bump_version(current, level)
    subjects = [message.split("\n", 1)[0] for message in messages]

    print(f"{current} -> {new} ({level})")
    for subject in subjects:
        print(f"  - {subject}")

    if args.dry_run:
        write_output(new, level)
        return

    for path in VERSION_FILES:
        path.write_text(replace_current(path.read_text(), current, new))
    for path in CHANGELOGS:
        prepend_changelog(path, new, subjects)
    write_output(new, level)


if __name__ == "__main__":
    main()
