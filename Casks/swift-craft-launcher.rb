cask "swift-craft-launcher" do
  version "0.1.9-beta"

  on_arm do
    sha256 :no_check
    url "https://github.com/suhang12332/Swift-Craft-Launcher/releases/download/v#{version}/SwiftCraftLauncher-v#{version}-arm64.dmg"
  end

  on_intel do
    sha256 :no_check
    url "https://github.com/suhang12332/Swift-Craft-Launcher/releases/download/v#{version}/SwiftCraftLauncher-v#{version}-x86_64.dmg"
  end

  name "Swift Craft Launcher"
  desc "Modern Minecraft launcher for macOS built with SwiftUI"
  homepage "https://suhang12332.github.io/swift-craft-launcher-web.github.io/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "Swift Craft Launcher.app"

  uninstall quit: "com.su.code.SwiftCraftLauncher"

  zap trash: [
    "~/Library/Application Support/Swift Craft Launcher",
    "~/Library/Caches/com.su.code.SwiftCraftLauncher",
    "~/Library/Logs/Swift Craft Launcher",
    "~/Library/Preferences/com.su.code.SwiftCraftLauncher.plist",
    "~/Library/Saved Application State/com.su.code.SwiftCraftLauncher.savedState"
  ]
end
