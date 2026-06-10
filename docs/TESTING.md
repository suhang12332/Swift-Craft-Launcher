# Testing Guide

## Run Tests

### Xcode

Use **Product → Test** (`⌘U`).

### Command Line

```bash
xcodebuild test \
  -project SwiftCraftLauncher.xcodeproj \
  -scheme SwiftCraftLauncher \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO
```

No CI secrets are required to run unit tests locally.

## Covered Modules (Phase 1)

| Module | Test File | Focus |
|--------|-----------|-------|
| `NBTParser` | `NBTParserTests.swift` | NBT encode/decode, gzip, servers.dat |
| `WorldNBTMapper` | `WorldNBTMapperTests.swift` | Seed/mode/difficulty mapping |
| `CommonUtil` | `CommonUtilTests.swift` | Version slugs, server info parsing |
| `CommonYggdrasilProfileListParser` | `CommonYggdrasilProfileListParserTests.swift` | Profile JSON formats |
| `CurseForgeManifestParser` | `CurseForgeManifestParserTests.swift` | manifest.json import |
| `CurseForgeService` | `CurseForgeServiceTests.swift` | CF ID 解析 |
| `ModrinthService` | `ModrinthServiceTests.swift` | primary 文件筛选 |
| `CurseForgeSlugHelper` | `CurseForgeSlugHelperTests.swift` | slug 规范化 |
| `PlayerUtils` | `PlayerUtilsTests.swift` | 离线 UUID |
| `CurseForgeFingerprint` | `CurseForgeFingerprintTests.swift` | fingerprint 哈希 |
| `FileDownloadCore` | `FileDownloadCoreTests.swift` | URL 解析 |

## Fixtures

Test fixtures live under `SwiftCraftLauncherTests/Fixtures/`:

- `yggdrasil/` — Yggdrasil profile list JSON
- `curseforge/` — CurseForge `manifest.json` samples

Load fixtures via `TestSupport.fixtureURL(...)`.

## What to Test

- Pure functions and parsers
- Round-trip serialization
- Edge cases and invalid input

Defer to later phases:

- SwiftUI snapshot tests
- Live network / Minecraft server ping
- Full game launch integration
