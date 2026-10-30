#!/usr/bin/env python3
"""
Validate the project's standard Swift file header.

Every Swift file must start with this header:

    //
    //  <FileName>.swift
    //  <ModuleName>
    //
    //  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
    //

An optional one-line description may appear between the leading "//" and the
copyright line (as used by a few existing files), e.g.:

    //
    //  FileName.swift
    //  CommonFeature
    //
    //  Short description of the file.
    //  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
    //

Additional comment blocks (e.g. license text) may follow after the header.

Usage:
    python3 .github/scripts/check_file_headers.py
    python3 .github/scripts/check_file_headers.py path/to/File.swift path/to/Dir
    python3 .github/scripts/check_file_headers.py --staged

Exit code:
    0 — all checked files have a valid header
    1 — one or more violations found (or no files matched)
"""

from __future__ import annotations

import argparse
import codecs
import re
import subprocess
import sys
from pathlib import Path

# ── Configuration ────────────────────────────────────────────────────────────

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIRS = [
    PROJECT_ROOT / "SwiftCraftLauncher",
    PROJECT_ROOT / "SwiftCraftLauncherTests",
]

# "© 2025-2026 ..." (a single year is accepted too).
COPYRIGHT_RE = re.compile(
    r"^//  © (\d{4})(?:-(\d{4}))? Swift Craft Launcher Team\. All rights reserved\.$"
)

# Module names are PascalCase identifiers, e.g. CommonFeature / Config.
MODULE_RE = re.compile(r"^//  ([A-Z][A-Za-z0-9]*)$")

HEADER_TEMPLATE = """\
//
//  {file_name}
//  {module_name}
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//"""

# ── Helpers ──────────────────────────────────────────────────────────────────


def collect_swift_files() -> list[Path]:
    files: list[Path] = []
    for directory in SOURCE_DIRS:
        if directory.is_dir():
            files.extend(sorted(directory.rglob("*.swift")))
    return files


def collect_staged_files() -> list[Path]:
    result = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
        cwd=PROJECT_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return [
        PROJECT_ROOT / name
        for name in result.stdout.splitlines()
        if name.endswith(".swift") and (PROJECT_ROOT / name).is_file()
    ]


def expand_paths(paths: list[str]) -> list[Path]:
    files: list[Path] = []
    for raw in paths:
        path = Path(raw)
        if not path.is_absolute():
            path = (PROJECT_ROOT / path).resolve()
        if path.is_dir():
            files.extend(sorted(path.rglob("*.swift")))
        elif path.is_file():
            if path.suffix == ".swift":
                files.append(path)
        else:
            print(f"⚠️  Skipping non-existent path: {raw}", file=sys.stderr)
    return files


def line_at(lines: list[str], index: int) -> str | None:
    return lines[index] if index < len(lines) else None


def describe_actual(value: str | None) -> str:
    return "<missing>" if value is None else repr(value)


def check_header(path: Path) -> list[str]:
    """Return a list of human-readable violations (empty means the header is valid)."""
    errors: list[str] = []

    data = path.read_bytes()
    if data.startswith(codecs.BOM_UTF8):
        errors.append("line 1: file starts with a UTF-8 BOM")

    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return errors + ["file is not valid UTF-8"]

    text = text.removeprefix(codecs.BOM_UTF8.decode("utf-8"))
    lines = text.splitlines()

    if not lines:
        return errors + ["file is empty"]

    def expect(index: int, expected: str | None = None, label: str = "") -> None:
        actual = line_at(lines, index)
        if expected is not None:
            if actual != expected:
                errors.append(
                    f"line {index + 1}: expected {expected!r}, got {describe_actual(actual)}"
                )
        elif actual is None:
            errors.append(f"line {index + 1}: {label} is missing")

    expect(0, "//")
    expect(1, f"//  {path.name}", "file name line")
    expect(3, "//")

    module_line = line_at(lines, 2)
    module_match = MODULE_RE.fullmatch(module_line or "")
    if not module_match:
        errors.append(
            "line 3: expected '//  <ModuleName>' with a PascalCase module name, "
            f"got {describe_actual(module_line)}"
        )

    # The header is the first contiguous block of "//" comments.
    block_end = -1
    for index, line in enumerate(lines):
        if not line.startswith("//"):
            break
        block_end = index
    if block_end < 0:
        return errors

    copyright_indexes = [
        index
        for index in range(4, block_end + 1)
        if COPYRIGHT_RE.fullmatch(lines[index])
    ]

    if not copyright_indexes:
        copyright_line = next(
            (lines[index] for index in range(4, block_end + 1) if lines[index].strip() != "//"),
            None,
        )
        errors.append(
            "expected "
            "'//  © <year>-<year> Swift Craft Launcher Team. All rights reserved.', "
            f"got {describe_actual(copyright_line)}"
        )
    elif len(copyright_indexes) > 1:
        lines_found = ", ".join(str(index + 1) for index in copyright_indexes)
        errors.append(f"copyright line appears more than once (lines {lines_found})")
    else:
        copyright_index = copyright_indexes[0]

        start_year = int(COPYRIGHT_RE.fullmatch(lines[copyright_index]).group(1))
        end_year = COPYRIGHT_RE.fullmatch(lines[copyright_index]).group(2)
        if end_year is not None and start_year > int(end_year):
            errors.append(
                f"line {copyright_index + 1}: copyright year range is reversed "
                f"({start_year}-{end_year})"
            )

        following_line = line_at(lines, copyright_index + 1)
        if following_line != "//":
            errors.append(
                f"line {copyright_index + 2}: expected '//' immediately after the "
                f"copyright line, got {describe_actual(following_line)}"
            )

    return errors


def expected_header(path: Path, module_name: str = "<ModuleName>") -> str:
    return HEADER_TEMPLATE.format(file_name=path.name, module_name=module_name)


# ── Main ─────────────────────────────────────────────────────────────────────


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check that Swift files start with the project's standard header."
    )
    parser.add_argument(
        "paths",
        nargs="*",
        help="Files or directories to check. Defaults to the whole project.",
    )
    parser.add_argument(
        "--staged",
        action="store_true",
        help="Only check Swift files staged in git (useful for pre-commit hooks).",
    )
    args = parser.parse_args()

    if args.staged and args.paths:
        parser.error("--staged cannot be combined with explicit paths")

    if args.staged:
        files = collect_staged_files()
    elif args.paths:
        files = expand_paths(args.paths)
    else:
        files = collect_swift_files()

    # De-duplicate while preserving order.
    files = list(dict.fromkeys(files))

    if not files:
        print("⚠️  No Swift files to check.")
        return 0

    violations: dict[Path, list[str]] = {}
    for path in files:
        errors = check_header(path)
        if errors:
            try:
                display = path.relative_to(PROJECT_ROOT)
            except ValueError:
                display = path
            violations[display] = errors

    if violations:
        print(f"\n❌ File header violations ({len(violations)}/{len(files)} files):\n")
        for display, errors in violations.items():
            print(f"  {display}")
            for error in errors:
                print(f"    - {error}")
            print("\n    Expected header:")
            for template_line in expected_header(Path(display)).splitlines():
                print(f"      {template_line}")
            print()
        return 1

    print(f"✅ All {len(files)} Swift files have a valid file header.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
