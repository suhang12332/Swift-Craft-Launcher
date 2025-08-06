# SwiftCraftLauncher

> 本项目采用 [GNU Affero General Public License v3.0](https://www.gnu.org/licenses/agpl-3.0.txt) 许可证开源。

🌐 **项目官网**: [https://suhang12332.github.io/swift-craft-launcher-web.github.io/](https://suhang12332.github.io/swift-craft-launcher-web.github.io/)

## 🚀 简介

SwiftCraftLauncher 是一个现代化的 macOS 版 Minecraft 启动器，为用户提供快速、高效的 Minecraft 游戏启动体验。通过简洁的界面和智能的功能，让您的 Minecraft 游戏启动变得更加便捷。
项目处理早期开发阶段：可以在[git action](https://github.com/suhang12332/Swift-Craft-Launcher/actions)中进行下载

## ✨ 主要特性

- 🎮 **Minecraft 游戏启动**: 支持启动各种版本的 Minecraft 游戏
- 🔐 **Microsoft 账户认证**: 完整的 Microsoft OAuth 认证流程，支持设备代码认证
- 📦 **Modrinth 项目集成**: 查看 Modrinth 上的项目详细信息，包括版本、作者和链接
- 🧩 **多加载器支持**: 
  - **Fabric Loader**: 集成 Fabric Loader 管理与自动安装
  - **Quilt Loader**: 支持 Quilt 模组生态，基于 Fabric 的现代化模组加载器
  - **NeoForge Loader**: 支持最新的 Forge 生态
  - **Forge Loader**: 支持经典 Forge 模组生态
- 🎨 **现代化用户界面**: 基于 SwiftUI 构建的现代化界面
- ⚡️ **高性能运行**: 优化的代码结构和缓存机制
- 🛠 **可自定义配置**: 支持 Java 路径、内存分配等个性化设置
- 🌍 **多语言支持**: 支持多种语言，包含国旗图标显示
- 📁 **智能路径管理**: Finder 风格的面包屑导航，支持长路径自动省略

## 🛠 技术栈

- **SwiftUI**: 现代化 UI 框架
- **Swift**: 主要编程语言
- **Combine**: 响应式编程
- **macOS**: 目标平台

## 🧩 加载器支持

SwiftCraftLauncher 支持多种流行的 Minecraft 模组加载器：

- **Fabric Loader**: 轻量级、高性能的模组加载器，专注于模块化设计
- **Quilt Loader**: 基于 Fabric 的现代化模组加载器，提供更好的开发体验和社区支持
- **Forge Loader**: 经典的模组加载器，拥有丰富的模组生态
- **NeoForge Loader**: Forge 生态的现代化分支，提供更好的性能和兼容性

所有加载器都支持自动安装、版本管理和依赖处理。

## 📦 安装要求

- macOS 11.0 或更高版本
- Xcode 13.0 或更高版本
- Swift 5.5 或更高版本
- Java 8 或更高版本（用于运行 Minecraft）

## 🚀 快速开始

1. 克隆仓库
```bash
git clone https://github.com/suhang12332/SwiftCraftLauncher.git
```

2. 打开项目
```bash
cd SwiftCraftLauncher
open SwiftCraftLauncher.xcodeproj
```

3. 在 Xcode 中构建并运行项目


## 🎮 游戏管理

- **版本管理**: 支持管理多个 Minecraft 版本
- **加载器支持**: 支持 Fabric、Quilt、Forge、NeoForge 等多种模组加载器
- **配置文件**: 每个游戏版本可独立配置 Java 路径、内存分配等
- **启动参数**: 支持自定义 JVM 和游戏启动参数
- **资源管理**: 支持 mod、datapack、shader、resourcepack 的一键下载和管理

## 📝 许可证

本项目采用 GNU Affero General Public License v3.0 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🤝 贡献

欢迎提交 Pull Requests 和 Issues！

## 📧 联系方式

如有任何问题或建议，请随时联系我。

## 🆕 近期更新

### 最新更新 (2024)
- 🔧 **代码优化**: 精简 MinecraftAuthService，移除冗余代码，提升性能和可维护性
- 🚀 **认证流程优化**: 简化 Microsoft OAuth 认证流程，提升用户体验
- 🧹 **代码清理**: 删除调试输出和未使用的代码，提升代码质量

### 功能更新
- 📦 **全局资源管理**: 新增全局资源添加 Sheet，支持 mod、datapack、shader、resourcepack 的一键下载、依赖检测与版本筛选
- 📁 **目录管理**: 资源详情页支持一键打开游戏目录（Finder）
- 🔧 **兼容性提升**: 兼容 macOS 14，更新 onChange API 用法，消除弃用警告
- ⚙️ **启动器优化**: 重构 Minecraft 启动命令构建器，JVM 启动参数拼接逻辑更简洁
- ☕️ **Java 管理**: 
  - Java 启动路径优先级：优先使用每个游戏 profile 单独配置的 Java 路径
  - Java 版本自动检测：选择 Java 路径后自动检测并显示版本
- 📊 **内存管理**: 全局内存设置支持区间滑块（Xms/Xmx），可视化设置最小/最大内存
- 🌍 **界面优化**: 
  - 多语言选择器支持国旗图标
  - 路径选择控件支持 Finder 风格的面包屑导航
- 🔥 **加载器支持**: 
  - **Quilt Loader**: 新增 Quilt 加载器支持，自动安装与管理
  - Fabric Loader 自动安装与管理
  - NeoForge Loader 管理与自动安装
  - Forge Loader 管理与自动安装
- 🛠 **技术改进**: 
  - Mod Classpath 优先级与 NeoForge 兼容性增强
  - SwiftUI 兼容性与循环依赖修复
  - 游戏图标存储优化，支持图片选择和拖入
  - 缓存机制优化，按命名空间拆分缓存文件
