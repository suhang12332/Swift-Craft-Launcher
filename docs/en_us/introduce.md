# Project Overview

Swift Craft Launcher is a native macOS Minecraft launcher built with SwiftUI, offering a smooth and efficient gaming experience. Designed specifically for modern macOS systems, it features comprehensive mod loader support, Microsoft account authentication, and intuitive game management.

## Core Features

### Basic Functions
- **Multi-version Minecraft Support** - ARM: 1.19+, Intel: Not tested
- **Microsoft Account Authentication** - Secure OAuth integration with device code flow support
- **Mod Loader Support** - Fabric, Quilt, Forge, and NeoForge with automatic installation
- **Resource Management** - One-click installation for mods, datapacks, shaders, and resource packs

### User Experience
- **Native macOS Design** - Built with SwiftUI, following Apple Human Interface Guidelines
- **Multilingual Support** - Localized interface with flag indicators
- **Smart Path Management** - Finder-style breadcrumb navigation with automatic truncation for long paths
- **Performance Optimization** - Efficient caching and memory management

### Advanced Configuration
- **Java Management** - Independent Java path configuration for each profile, with automatic version detection
- **Memory Allocation** - Visual slider for setting Xms/Xmx parameters *(coming soon)*
- **Custom Launch Arguments** - Custom JVM and game parameters *(coming soon)*

## System Requirements

- **macOS**: 14.0 or later
- **Java**: 8 or later (for Minecraft runtime)

## Installation

### Using Homebrew Tap (Recommended)
```bash
# Method 1: One-click install
brew install --cask suhang12332/swiftcraftlauncher/swift-craft-launcher

# Method 2: Add Tap then install
brew tap suhang12332/swiftcraftlauncher
brew install --cask swift-craft-launcher
```

> **💡 Tip**: We have created a dedicated [Homebrew Tap](https://github.com/suhang12332/homebrew-swiftcraftlauncher) for SwiftCraft Launcher.

### Precompiled Releases
Download the latest version from [GitHub Releases](https://github.com/suhang12332/Swift-Craft-Launcher/releases/latest).

> **⚠️ Note**: All currently available versions are test builds; a stable release is coming soon.

### Build from Source
1. **Clone the repository**
   ```bash
   git clone https://github.com/suhang12332/Swift-Craft-Launcher.git
   cd Swift-Craft-Launcher
   ```

2. **Open in Xcode**
   ```bash
   open SwiftCraftLauncher.xcodeproj
   ```

3. **Build and Run** using Xcode (⌘R)

**Build Requirements:**
- Xcode 13.0+
- Swift 5.5+

## Technical Architecture

| Component | Technology |
|-----------|------------|
| **UI Framework** | SwiftUI |
| **Programming Language** | Swift |
| **Reactive Programming** | Combine |
| **Target Platform** | macOS 14.0+ |

## Open Source License

This project is licensed under the GNU Affero General Public License v3.0. For details, see the [LICENSE](LICENSE) file.

## Community & Support

- **Official QQ Group**: [1057517524](https://qm.qq.com/cgi-bin/qm/qr?k=1057517524)
- **Issue Reporting**: [GitHub Issues](https://github.com/suhang12332/Swift-Craft-Launcher/issues)
- **Feature Suggestions**: [GitHub Discussions](https://github.com/suhang12332/Swift-Craft-Launcher/discussions)

## Contributing

We welcome all forms of contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for:
- Code style and standards
- Pull Request process
- Issue reporting guidelines

## Acknowledgements

Special thanks to the following projects for their contributions to this launcher:

- **[Archify - Universal Binary Optimization Tool for macOS Applications](https://github.com/Oct4Pie/archify)**