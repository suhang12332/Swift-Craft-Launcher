#!/usr/bin/env python3
"""
Check Swift source files against project coding rules.

Rules enforced:
  1. File header — every .swift file must start with a valid copyright header:
       //
       //  <FileName>.swift
       //  <ModuleName>
       //
       //  © 20xx-xxxx Swift Craft Launcher Team. All rights reserved.
       //
  2. Comment rule — "MARK" comments (// MARK:, // MARK: -, /* MARK */) are forbidden.

Exit code:
  0 — all checks passed
  1 — one or more violations found
"""

import re
import sys
from pathlib import Path

# ── Configuration ────────────────────────────────────────────────────────────

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SWIFT_SOURCE_DIRS = [
    PROJECT_ROOT / "SwiftCraftLauncher",
    PROJECT_ROOT / "SwiftCraftLauncherTests",
]

COPYRIGHT_PATTERN = re.compile(
    r"^//\s*\n"
    r"//\s+\S+\.swift\n"
    r"//\s+\S+\n"
    r"(?://\s*\n)"
    r"(?://.*\n)*?"
    r"//\s+©\s+\d{4}(?:-\d{4})?\s+Swift Craft Launcher Team\. All rights reserved\.\n"
    r"//\s*\n",
    re.MULTILINE,
)

MARK_PATTERN = re.compile(
    r"(?:///\s*MARK|//\s*MARK\s*:|/\*\s*MARK\s*:)",
    re.IGNORECASE,
)

# ── Helpers ──────────────────────────────────────────────────────────────────

def collect_swift_files() -> list[Path]:
    files: list[Path] = []
    for d in SWIFT_SOURCE_DIRS:
        if d.is_dir():
            files.extend(sorted(d.rglob("*.swift")))
    return files


def check_header(path: Path, lines: list[str]) -> list[str]:
    """Return a list of header-related error messages (empty = OK)."""
    errors: list[str] = []
    text = "".join(lines)

    if not COPYRIGHT_PATTERN.search(text):
        errors.append("  Missing or malformed copyright header")

    # Verify first non-blank line is "//"
    for line in lines:
        stripped = line.strip()
        if stripped:
            if stripped != "//":
                errors.append(
                    f"  First non-blank line should be '//', got: {stripped!r}"
                )
            break

    # Verify second non-blank line matches "<Name>.swift"
    non_blank = [l.strip() for l in lines if l.strip()]
    if len(non_blank) >= 2 and not re.match(r"^//\s+\S+\.swift$", non_blank[1]):
        errors.append(
            f"  Second non-blank line should be '//  <Name>.swift', got: {non_blank[1]!r}"
        )

    # Verify third non-blank line is "//  <ModuleName>"
    if len(non_blank) >= 3 and not re.match(r"^//\s+\S+$", non_blank[2]):
        errors.append(
            f"  Third non-blank line should be '//  <ModuleName>', got: {non_blank[2]!r}"
        )

    return errors


def check_no_mark(path: Path, lines: list[str]) -> list[str]:
    """Return a list of MARK-related error messages (empty = OK)."""
    errors: list[str] = []
    for i, line in enumerate(lines, start=1):
        if MARK_PATTERN.search(line):
            errors.append(f"  Line {i}: {line.rstrip()!r}")
    return errors

# ── Main ─────────────────────────────────────────────────────────────────────

def main() -> int:
    files = collect_swift_files()
    if not files:
        print("⚠️  No Swift files found.")
        return 0

    header_violations: dict[str, list[str]] = {}
    mark_violations: dict[str, list[str]] = {}

    for path in files:
        rel = path.relative_to(PROJECT_ROOT)
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)

        h_errs = check_header(path, lines)
        if h_errs:
            header_violations[str(rel)] = h_errs

        m_errs = check_no_mark(path, lines)
        if m_errs:
            mark_violations[str(rel)] = m_errs

    # ── Report ───────────────────────────────────────────────────────────────
    total_files = len(files)
    ok = True

    if header_violations:
        ok = False
        print(f"\n❌ FILE HEADER violations ({len(header_violations)}/{total_files} files):\n")
        for f, errs in header_violations.items():
            print(f"  {f}")
            for e in errs:
                print(f"    {e}")
        print()

    if mark_violations:
        ok = False
        print(f"❌ MARK COMMENT violations ({len(mark_violations)}/{total_files} files):\n")
        for f, errs in mark_violations.items():
            print(f"  {f}")
            for e in errs:
                print(f"    {e}")
        print()

    if ok:
        print(f"✅ All {total_files} Swift files passed header & comment checks.")
        return 0
    else:
        return 1


if __name__ == "__main__":
    sys.exit(main())
