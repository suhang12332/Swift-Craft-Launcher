# Homebrew Cask

这个目录包含 SwiftCraft Launcher 的 Homebrew Cask 配置。本项目同时作为代码仓库和 Homebrew Tap 使用。

## 安装方式

```bash
# 推荐方式：使用 Tap
brew tap suhang12332/Swift-Craft-Launcher
brew install --cask swift-craft-launcher

# 或者一键安装
brew install --cask suhang12332/Swift-Craft-Launcher/swift-craft-launcher
```

## 文件说明

- `swift-craft-launcher.rb` - Homebrew Cask 配置文件
  - 支持 Apple Silicon (ARM64) 和 Intel (x86_64) 架构
  - 自动检测系统架构并下载对应版本
  - 包含完整的安装和卸载配置

## 更新版本

当发布新版本时，只需要修改 `swift-craft-launcher.rb` 中的 `version` 行：

```ruby
version "新版本号"
```

## 架构支持

- **Apple Silicon (M1/M2/M3/M4)**: 下载 `*-arm64.dmg` 文件
- **Intel**: 下载 `*-x86_64.dmg` 文件

## 清理配置

卸载时会清理以下位置的文件：
- `~/Library/Application Support/Swift Craft Launcher`
- `~/Library/Caches/com.su.code.SwiftCraftLauncher`
- `~/Library/Logs/Swift Craft Launcher`
- `~/Library/Preferences/com.su.code.SwiftCraftLauncher.plist`
- `~/Library/Saved Application State/com.su.code.SwiftCraftLauncher.savedState`
