# 貢獻指南

[English](../CONTRIBUTING.md) | [简体中文](CONTRIBUTING.md) | 繁體中文

歡迎你為 Swift Craft Launcher 貢獻！謝謝你願意參與。請先看這份指南，可以讓我們協作更順暢，也能讓你的貢獻更容易被接納。

### 1. 行為準則（Code of Conduct）

尊重他人：保持友善、建設性、不攻擊。

開放與包容：歡迎各種背景的貢獻者。

清晰溝通：Issue、PR 描述要盡量清楚，避免誤解。

---

### 2. 如何報告問題（Issue）

當你發現 bug 或者有改進建議：

在 GitHub 上的 Issues 裡新開一個 issue。

標題要簡潔醒目，例如：

「[BUG] 啟動時崩潰在 macOS 14.1 – Java 路徑未找到」

內容包含：

作業系統版本（macOS + 版本號）

Swift Craft Launcher 的版本（release 或 commit hash）

你做了什麼 → 期望是什麼 → 實際發生什麼

如果可以的話，附上 error log 或者截圖

---

### 3. 貢獻程式碼（Pull Request）流程

確保你 Fork 了專案，並把原作者最新 dev 分支同步到你的倉庫。

從最新的 dev 分支建立一個功能分支（feature branch）：

dev → feature/你的描述

例如 feature/fix-java-path 或 feature/add-mod-support。

在 feature 分支上做改動。改動內容應專注一件事情，盡量小而明確。

寫清楚 commit message：

用英文或者中英文混合明確說明做了什麼

用動詞開頭，例如「Fix …」、「Add …」、「Improve …」等

本地測試沒問題之後，把分支 push 到你 fork 的倉庫。

到 GitHub 上建立 PR，目標庫（base repo）是原作者倉庫，base 分支是 dev，compare 分支是你的 feature 分支。

在 PR 描述裡包含：

為什麼要做這個改動

改動是什麼

如果可能，有效果截圖或者 log

等待 Review，可能會有建議要改的地方，請耐心修改。

---

### 4. 程式碼風格和品質

本專案使用 [SwiftLint](https://github.com/realm/SwiftLint) 進行程式碼風格檢查，提交前請確保程式碼通過 Lint。

#### 4.1 本地執行 SwiftLint

```bash
# 安裝（若未安裝）
brew install swiftlint

# 檢查全部檔案
swiftformat . --swift-version 6.1

# 僅檢查有改動的檔案（推薦，速度快）
git diff --cached --name-only | grep '\.swift$' | xargs swiftformat
```

完整設定見專案根目錄 `.swiftlint.yml`。

#### 4.3 風格要點

- 語言是 Swift，UI 用 SwiftUI。請遵守 Swift 的命名規範（CamelCase、清晰的變數／函式名）
- 註解要合理：公共 API／複雜邏輯最好有註解
- 遵守已有的專案結構，不要把檔案亂放
- 寫測試（如果合適），確保改動沒有破壞已有功能
- 注意處理 edge cases，異常情況不要崩潰
- 如果確實需要違反某條規則，在該行上方新增 `// swiftlint:disable:next <rule_name>`，並在後續恢復

---

### 5. CI 要求

所有 Pull Request 在合併前必須通過 CI 流水線檢查。CI 包含以下內容：

- **SwiftLint**：程式碼必須通過 `swiftlint lint --strict`，不能有違規
- **SwiftFormat**：程式碼必須通過 `swiftformat . --swift-version 6.1` 格式檢查
- **本地化**：所有語言的本地化字串必須完整
- **單元測試**：所有單元測試必須通過

推送前可在本地執行以下檢查：

```bash
# SwiftLint
swiftlint lint --strict

# SwiftFormat
swiftformat . --swift-version 6.1

# 單元測試
xcodebuild test \
  -project SwiftCraftLauncher.xcodeproj \
  -scheme SwiftCraftLauncher \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO
```

---

### 6. 分支管理規則

dev 是開發主分支，用於合併所有功能／修復之後再發布／打包

新功能／修復請都基於 dev 分支建立 feature 分支

PR 永遠以 dev 為 base 分支提交

---

### 7. 本地開發環境

使用 Xcode（版本 >= 專案要求）

確保本地 Swift 版本符合專案要求

可能要安裝對應的 Java 版本（若啟動器相關功能依賴）

編譯、執行、手動測試功能是否一切正常

### 7.1 執行單元測試

```bash
xcodebuild test \
  -project SwiftCraftLauncher.xcodeproj \
  -scheme SwiftCraftLauncher \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO
```

或在 Xcode 中使用 **Product → Test**（`⌘U`）。
---

### 8. 合併與發布

專案維護者會 Review PR，如果通過，會合併到 dev

當 dev 達到一個穩定狀態或者準備發布版本時，會建立 release tag

發布版本前會進行測試確認，無重大 BUG

---

### 9. 感謝你！

感謝你願意貢獻時間、精力。每一個 issue、每一個 PR、每一點建議都很寶貴。
