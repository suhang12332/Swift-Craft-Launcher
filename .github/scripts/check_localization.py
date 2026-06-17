#!/usr/bin/env python3
"""Check that all translatable keys in Localizable.xcstrings have translations for all languages."""

import json
import sys
from pathlib import Path


def check_localization(xcstrings_path: Path) -> bool:
    with open(xcstrings_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    source_lang = data.get("sourceLanguage", "en")
    strings = data.get("strings", {})

    all_languages: set[str] = set()
    for key_data in strings.values():
        localizations = key_data.get("localizations", {})
        all_languages.update(localizations.keys())
    all_languages.discard(source_lang)

    if not all_languages:
        print("⚠️  No target languages found in xcstrings file.")
        return True

    missing: dict[str, list[str]] = {}
    empty: dict[str, list[str]] = {}

    for key, key_data in strings.items():
        if not key_data.get("shouldTranslate", True):
            continue

        localizations = key_data.get("localizations", {})

        for lang in sorted(all_languages):
            if lang not in localizations:
                missing.setdefault(lang, []).append(key)
                continue

            loc = localizations[lang]
            unit = loc.get("stringUnit", {})
            if unit:
                value = unit.get("value", "")
                state = unit.get("state", "")
                if not value and state != "translated":
                    empty.setdefault(lang, []).append(key)
                continue

            variations = loc.get("variations", {})
            if variations:
                has_content = False
                plural = variations.get("plural", {})
                for form_data in plural.values():
                    unit = form_data.get("stringUnit", {})
                    if unit.get("value"):
                        has_content = True
                        break
                if not has_content:
                    empty.setdefault(lang, []).append(key)
                continue

            empty.setdefault(lang, []).append(key)

    has_issues = False

    if missing:
        has_issues = True
        print(f"❌ Missing translations for {len(missing)} language(s):\n")
        for lang in sorted(missing.keys()):
            keys = missing[lang]
            print(f"  [{lang}] missing {len(keys)} key(s):")
            for k in keys[:10]:
                print(f"    - {k}")
            if len(keys) > 10:
                print(f"    ... and {len(keys) - 10} more")
            print()

    if empty:
        has_issues = True
        print(f"❌ Empty translations for {len(empty)} language(s):\n")
        for lang in sorted(empty.keys()):
            keys = empty[lang]
            print(f"  [{lang}] empty {len(keys)} key(s):")
            for k in keys[:10]:
                print(f"    - {k}")
            if len(keys) > 10:
                print(f"    ... and {len(keys) - 10} more")
            print()

    if not has_issues:
        print(f"✅ Localization check passed: {len(strings)} keys, {len(all_languages)} languages")
        return True

    total_missing = sum(len(v) for v in missing.values())
    total_empty = sum(len(v) for v in empty.values())
    print(f"💡 Total: {total_missing} missing, {total_empty} empty translations")
    return False


if __name__ == "__main__":
    project_root = Path(__file__).resolve().parents[2]
    xcstrings = project_root / "SwiftCraftLauncher" / "Resources" / "Localizable.xcstrings"

    if not xcstrings.exists():
        print(f"❌ File not found: {xcstrings}")
        sys.exit(1)

    ok = check_localization(xcstrings)
    sys.exit(0 if ok else 1)
