# 启动器设置项
> The SCL Launcher provides a variety of configuration options for you to set.

## 5.1 General
![5-1_1](../../resources/settings/5-1_1.png)
### 5.1.1 Language
- You can set the launcher interface language. Your changes will take effect after restarting the launcher.
### 5.1.2 Appearance
- You can set the launcher appearance to light, dark, or follow the system. The effects are shown below.
![5-1-2_1](../../resources/settings/5-1-2_1.png)
![5-1-2_2](../../resources/settings/5-1-2_2.png)
### 5.1.3 Working Directory
- You can set the launcher’s working directory. All game files managed by the launcher will be placed in this folder, as shown below.
![5-1-3_1](../../resources/settings/5-1-3_1.png)
![5-1-3_2](../../resources/settings/5-1-3_2.png)
> Note: After changing the working directory, games in the original path will no longer appear in the "Game List." It is recommended to transfer or re-download them. It’s best to change the working directory the first time you open the launcher.
### 5.1.4 Download Settings
- The number of parallel downloads largely determines your download speed, but higher concurrency also brings greater performance overhead.
- If you are not familiar with the meanings of the Minecraft version URL, Modrinth API URL, and Git proxy URL, please do not modify them. Changing them may cause game resources to fail to download.
> If you accidentally changed them, please restore them to their default values. \
> Minecraft version URL: https://launchermeta.mojang.com/mc/game/version_manifest.json \
> Modrinth API URL: https://api.modrinth.com/v2 \
> Git proxy URL: https://ghfast.top

## 5.2 Tabs
- The data pack feature is under development. Stay tuned...

## 5.3 Game
![5-3_1](../../resources/settings/5-3_1.png)
### 5.3.1 Auto Dependency Handling
- When this option is enabled, any required dependencies for downloaded resources will be downloaded automatically, without pop-up notifications. The following page will not appear.
![5-3-1_1](../../resources/settings/5-3-1_1.png)
### 5.3.2 Java Path
- You can change this option to select a different Java version to launch the game.
> Below are MC versions and their minimum required Java versions: \
> 1.12 - Java 8 \
> 1.17 - Java 16 \
> 1.18 - Java 17 \
> 1.20.5 - Java 21 (64-bit)
### 5.3.3 Global Memory Allocation
- You can control the amount of memory allocated to your game. The minimum is 512MB. Generally, larger modpacks require more memory.