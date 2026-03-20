<div align="center">
  <img src="../SwiftCraftLauncher/Assets.xcassets/AppIcon.appiconset/mac512pt2x.png" alt="SwiftCraftLauncher" width="128" height="128">
  
  # 🚀 Swift Craft Launcher
  
  **✨ 現代化的 macOS Minecraft 啟動器 ✨**
  
  [![Swift Craft Launcher](https://img.shields.io/badge/Swift%20Craft%20Launcher-SCL-orange.svg?logo=swift)](https://github.com/suhang12332/Swift-Craft-Launcher)
  [![Swift](https://img.shields.io/badge/Swift-5.5+-red.svg?logo=swift)](https://swift.org/)

  [![QQ群](https://img.shields.io/badge/QQ%E7%BE%A4-1057517524-blue.svg?logo=tencentqq)](https://qm.qq.com/cgi-bin/qm/qr?k=1057517524)
  [![Discord](https://img.shields.io/badge/Discord-blue.svg?logo=discord)](https://discord.gg/gYESVa3CZd)

  [![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg?logo=gnu)](https://www.gnu.org/licenses/agpl-3.0)
  [![latest-release](https://img.shields.io/github/v/release/suhang12332/Swift-Craft-Launcher?label=latest-release&logo=github)](https://github.com/suhang12332/Swift-Craft-Launcher/releases/latest)
  [![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg?logo=apple)](https://developer.apple.com/macos/)
  [![Homebrew](https://img.shields.io/badge/Homebrew-available-green.svg?logo=homebrew)](https://formulae.brew.sh/cask/swiftcraft-launcher)
  [![Contributors](https://img.shields.io/github/contributors/suhang12332/Swift-Craft-Launcher?color=ee8449&logo=githubsponsors)](https://github.com/suhang12332/Swift-Craft-Launcher/graphs/contributors)
  
  🌐 [官網](https://suhang12332.github.io/Swift-Craft-Launcher-Assets/web/) • 💾 [下載](https://github.com/suhang12332/Swift-Craft-Launcher/releases/latest) • 📚 [文檔](https://suhang12332.github.io/Swift-Craft-Launcher-Assets/web/)
  
  [🇨🇳简体中文](README_zh-CN.md) | **🇭🇰繁體中文** | [🇬🇧English](../README.md)
</div>

---

## 🎯 專案概述

Swift Craft Launcher 是一款採用 SwiftUI 構建的原生 macOS Minecraft 啟動器 🍎，提供流暢高效的遊戲體驗。專為現代 macOS 系統設計，整合全面的模組載入器支援、Microsoft 帳戶認證和直觀的遊戲管理功能。

<div align="center">
  <img src="https://s2.loli.net/2025/08/12/pTPxSJh1bCzmGKo.png" alt="SwiftCraftLauncher 截圖" width="800">
</div>

## ✨ 核心特色

### 🧩 基礎功能
- **🔄 多版本 Minecraft 支援** - ARM: 1.13+，Intel: 未測試
- **🔐 Microsoft 帳戶認證** - 安全的 OAuth 整合，支援裝置代碼流程
- **🧰 模組載入器支援** - 支援 Fabric、Quilt、Forge 和 NeoForge 自動安裝
- **📦 資源管理** - 一鍵安裝模組、資料包、光影和資源包

### 💻 用戶體驗
- **🎨 原生 macOS 設計** - 基於 SwiftUI，遵循 Apple 人機介面指南
- **🌍 多語言支援** - 本地化介面，支援國旗標識
- **🗂️ 智慧路徑管理** - Finder 風格的麵包屑導航，自動截斷長路徑
- **⚡ 效能最佳化** - 高效的快取和記憶體管理機制

### ⚙️ 進階配置
- **☕ Java 管理** - 每個設定檔獨立的 Java 路徑配置，版本自動偵測
- **🧠 記憶體分配** - 視覺化範圍滑桿設定 Xms/Xmx 參數
- **🔧 自訂啟動參數** - JVM 和遊戲參數自訂

## 📋 系統要求

- **💻 macOS**: 14.0 或更高版本
- **☕️ Java**: 8 或更高版本（用於 Minecraft 執行時）

## 📥 安裝方式

### 🍺 使用 Homebrew Tap (推薦)
```bash
# 方法 1：一鍵安裝
brew install --cask suhang12332/swiftcraftlauncher/swift-craft-launcher

# 方法 2：新增 Tap 後安裝
brew tap suhang12332/swiftcraftlauncher
brew install --cask swift-craft-launcher
```

> **💡 提示**: 我們為 Swift Craft Launcher 建立了專用的 [Homebrew Tap](https://github.com/suhang12332/homebrew-swiftcraftlauncher)

### 💾 預編譯版本
從 [GitHub Releases](https://github.com/suhang12332/Swift-Craft-Launcher/releases/latest) 下載最新版本。

> **⚠️ 注意**: 當前可下載的版本均為測試版本，穩定版本即將發佈。

### ❓ 常見問題
請訪問 [FAQ](FAQ.md)

### 🔨 從原始碼建置
1. **📥 複製儲存庫**
   ```bash
   git clone https://github.com/suhang12332/Swift-Craft-Launcher.git
   cd Swift-Craft-Launcher
   ```

2. **🛠️ 在 Xcode 中開啟**
   ```bash
   open SwiftCraftLauncher.xcodeproj
   ```

3. **🚀 建置並執行** 使用 Xcode (⌘R)

**建置要求：**
- Xcode 13.0+
- Swift 5.5+

## 🧪 技術架構

| 元件 | 技術 |
|------|------|
| **🎨 UI 框架** | SwiftUI |
| **💻 開發語言** | Swift |
| **🔄 反應式程式設計** | Combine |
| **📱 目標平台** | macOS 14.0+ |

## 📜 開源協議

本專案採用 GNU Affero General Public License v3.0 開源授權。詳細資訊請查看 [LICENSE](../LICENSE) 檔案。

**附加條款**：本專案包含附加條款，要求聲明來源並禁止使用相同軟體名稱。詳細資訊請查看：
- [简体中文](ADDITIONAL_TERMS.md)
- [繁體中文](ADDITIONAL_TERMS_zh-TW.md)
- [English](ADDITIONAL_TERMS_en.md)

## 🤝 社群與支援

- **👥 官方 QQ 群**: [1057517524](https://qm.qq.com/cgi-bin/qm/qr?k=1057517524)
- **Discord**: [Discord](https://discord.gg/gYESVa3CZd)
- **🐛 問題回報**: [GitHub Issues](https://github.com/suhang12332/Swift-Craft-Launcher/issues)
- **💡 功能建議**: [GitHub Discussions](https://github.com/suhang12332/Swift-Craft-Launcher/discussions)

## 🌟 參與貢獻

我們歡迎各種形式的貢獻！請查看我們的 [貢獻指南](../CONTRIBUTING.md) 了解以下內容：
- 程式碼風格和標準
- Pull Request 流程
- 問題回報指南

## 🙏 致謝

特別感謝以下專案對本啟動器的貢獻：

- **[Archify](https://github.com/Oct4Pie/archify)** - macOS 應用程式通用二進位最佳化工具

- **[curseforge-fingerprint](https://github.com/meza/curseforge-fingerprint)** - CurseForge 模組檔案指紋演算法封裝

---

<div align="center">
  <strong>🎮 為 Minecraft 社群用心製作 ❤️</strong>
</div>
