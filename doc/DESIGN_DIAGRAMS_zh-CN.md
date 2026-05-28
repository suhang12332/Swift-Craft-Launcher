# Swift Craft Launcher — 设计图与流程图

> 本文档用于说明软件总体架构、功能模块划分及主要业务流程。图中模块命名与工程目录（`CommonFeature` / `PlayerFeature` / `GameFeature` / `ModPackFeature` 等）对应。

---

## 1. 系统总体架构

```mermaid
flowchart TB
    subgraph UI["表现层 SwiftUI"]
        MainView["MainView 主界面"]
        SettingsView["SettingsView 设置"]
        PlayerViews["玩家 / 认证视图"]
        GameViews["游戏实例视图"]
        ResourceViews["资源 / 模组视图"]
        ModPackViews["整合包视图"]
        SkinViews["皮肤 / 披风视图"]
    end

    subgraph AppCore["应用核心"]
        App["SwiftCraftLauncherApp"]
        AppServices["AppServices 依赖注入"]
        ThemeManager["ThemeManager 主题"]
        GeneralSettings["GeneralSettingsManager"]
    end

    subgraph Domain["业务层"]
        GameLaunchUC["GameLaunchUseCase"]
        GameRepo["GameRepository"]
        PlayerVM["PlayerListViewModel"]
        AuthSvc["MinecraftAuthService / YggdrasilAuthService"]
        JavaMgr["JavaManager"]
        DownloadMgr["DownloadManager"]
        ModPackFlow["整合包安装状态机"]
    end

    subgraph Data["数据与系统"]
        Keychain["KeychainManager"]
        UserDefaults["UserDefaults / AppStorage"]
        FileSystem["工作目录 / .minecraft"]
        Network["HTTP API CurseForge 等"]
        Process["GameProcessManager 子进程"]
    end

    App --> UI
    UI --> AppServices
    AppServices --> Domain
    Domain --> Data
    MainView --> GameLaunchUC
    PlayerViews --> AuthSvc
    GameViews --> GameRepo
```

---

## 2. 功能模块结构图

```mermaid
mindmap
  root((Swift Craft Launcher))
    账号与玩家
      官方 Xbox 登录
      第三方 Yggdrasil
      玩家列表与资料
      Token 校验与刷新
    游戏实例
      创建 / 编辑 / 删除
      版本与启动参数
      存档信息
      启动 / 停止
    运行环境
      Java 检测
      Java 下载安装
      路径配置
    模组与资源
      加载器安装 Forge Fabric
      在线搜索筛选
      下载安装启用禁用
    整合包
      本地导入
      URL 唤起导入
      依赖解析安装
    个性化
      皮肤预览
      披风管理
    系统维护
      Sparkle 更新检查
      通用设置 语言 主题 代理
      公告与缓存
```

---

## 3. 主界面信息架构

```mermaid
flowchart LR
    Main["MainView"] --> Sidebar["侧边栏"]
    Main --> Content["内容区"]

    Sidebar --> Games["游戏列表"]
    Sidebar --> Players["玩家"]
    Sidebar --> Resources["资源中心"]
    Sidebar --> ModPacks["整合包"]
    Sidebar --> More["更多功能"]

    Content --> GameDetail["游戏详情 / 启动"]
    Content --> ResourceBrowser["资源浏览安装"]
    Content --> ModPackUI["整合包管理"]

    Main --> MenuBar["MenuBarExtra 状态栏"]
    Main --> Settings["系统设置窗口"]
```

---

## 4. 应用启动流程

```mermaid
flowchart TD
    Start([应用启动]) --> InitApp["SwiftCraftLauncherApp.init"]
    InitApp --> Services["AppServices.freeze 冻结依赖"]
    InitApp --> Theme["ThemeManager 应用外观"]
    InitApp --> Cache["配置 URLCache / 通知"]

    Services --> MainWin["打开主窗口 MainView"]
    MainWin --> Task["异步任务"]
    Task --> Update["Sparkle 更新检查"]
    Task --> Friends["好友在线状态轮询"]

    MainWin --> OnURL["监听 onOpenURL"]
    OnURL --> ModPackURL{"是否为整合包链接?"}
    ModPackURL -->|是| Import["OpenURLModPackImportPresenter"]
    ModPackURL -->|否| Other["其他深链处理"]
```

---

## 5. 账号登录认证流程

```mermaid
sequenceDiagram
    actor User as 用户
    participant UI as 认证界面
    participant Auth as AuthService
    participant Browser as 系统浏览器
    participant API as Mojang / 第三方 API
    participant Store as Keychain

    User->>UI: 选择登录方式并发起
    UI->>Auth: startAuthentication()
    Auth->>Browser: ASWebAuthenticationSession
    Browser->>User: 完成 OAuth 授权
    Browser-->>Auth: 授权码 redirect
    Auth->>API: 换取 Token / Profile
    API-->>Auth: access_token profile
    Auth->>Store: 安全存储凭证
    Auth-->>UI: authState = authenticated
    UI-->>User: 显示玩家信息
```

```mermaid
flowchart TD
    LoginStart([开始登录]) --> Type{"登录类型"}
    Type -->|正版| MSAuth["Microsoft / Xbox 流程"]
    Type -->|外置| Ygg["YggdrasilAuthService"]
    MSAuth --> WebAuth["浏览器授权"]
    Ygg --> WebAuth
    WebAuth --> Token["获取 Token"]
    Token --> Profile["拉取玩家档案"]
    Profile --> Save["写入 Keychain + 玩家列表"]
    Save --> Done([登录完成])
```

---

## 6. 游戏实例管理流程

```mermaid
flowchart TD
    A([游戏管理入口]) --> B{"用户操作"}
    B -->|新建| C["选择版本 / 加载器"]
    B -->|编辑| D["修改 JVM / 目录 / 模组"]
    B -->|复制| E["克隆实例配置"]
    B -->|删除| F["移除配置与可选文件"]

    C --> G["GameRepository 持久化"]
    D --> G
    E --> G
    F --> G
    G --> H["SelectedGameManager 选中态"]
    H --> I["主界面展示实例详情"]
```

---

## 7. 游戏启动流程

```mermaid
flowchart TD
    Launch([用户点击启动]) --> Select["确认当前玩家 + 游戏实例"]
    Select --> JavaCheck{"Java 是否可用?"}
    JavaCheck -->|否| JavaGuide["提示下载 / 配置 Java"]
    JavaCheck -->|是| TokenCheck["校验并刷新玩家 Token"]
    TokenCheck -->|失败| ErrAuth["提示重新登录"]
    TokenCheck -->|成功| BuildCmd["生成 launchCommand"]
    BuildCmd --> Inject["注入认证参数到命令行"]
    Inject --> Process["GameProcessManager 启动子进程"]
    Process --> Status["GameStatusManager 更新运行状态"]
    Status --> Running([游戏运行中])
    Running --> Stop{"用户停止?"}
    Stop -->|是| Kill["终止进程并清理状态"]
```

```mermaid
sequenceDiagram
    participant UI
    participant UC as GameLaunchUseCase
    participant Cmd as MinecraftLaunchCommand
    participant Auth as MinecraftAuthService
    participant Proc as GameProcessManager

    UI->>UC: launch(game, player)
    UC->>Cmd: launchGameThrowing()
    Cmd->>Auth: validatePlayerTokenBeforeLaunch()
    Auth-->>Cmd: validatedPlayer
    Cmd->>Proc: 启动 Java 进程
    Proc-->>UI: 状态回调 / 错误提示
```

---

## 8. Java 运行时获取与配置

```mermaid
flowchart TD
    J0([Java 管理]) --> J1["JavaManager 扫描本机"]
    J1 --> J2{"是否满足游戏要求?"}
    J2 -->|是| J3["绑定到游戏实例"]
    J2 -->|否| J4["JavaDownloadManager"]
    J4 --> J5["选择版本下载"]
    J5 --> J6["DownloadManager 拉取运行时"]
    J6 --> J7["解压并注册路径"]
    J7 --> J3
    J3 --> J8([启动时使用对应 Java])
```

---

## 9. 模组加载器与在线资源安装

```mermaid
flowchart TD
    R0([资源中心]) --> R1["选择资源类型 mod / datapack / shader / pack"]
    R1 --> R2["搜索 / 筛选 CurseForge 等"]
    R2 --> R3["用户确认安装"]
    R3 --> R4{"需要加载器?"}
    R4 -->|是| R5["安装 Forge / Fabric 等"]
    R4 -->|否| R6["DownloadManager 下载文件"]
    R5 --> R6
    R6 --> R7["写入游戏 mods 等目录"]
    R7 --> R8["ResourceEnableDisableManager 启用状态"]
    R8 --> R9([安装完成])
```

---

## 10. 整合包导入安装流程

```mermaid
flowchart TD
    M0([整合包入口]) --> M1{"导入方式"}
    M1 -->|本地文件| M2["选择 .zip / .mrpack"]
    M1 -->|URL 唤起| M3["onOpenURL 解析链接"]
    M1 -->|在线| M4["整合包下载 Sheet"]

    M2 --> M5["解析 manifest 与依赖"]
    M3 --> M5
    M4 --> M5
    M5 --> M6["ModPackInstallState 安装状态机"]
    M6 --> M7["下载缺失文件"]
    M7 --> M8["安装 mods / 配置 / 覆盖"]
    M8 --> M9["创建或更新游戏实例"]
    M9 --> M10([可启动新实例])
```

---

## 11. 皮肤与披风管理

```mermaid
flowchart LR
    S0([外观管理]) --> S1["加载当前玩家皮肤"]
    S1 --> S2["SkinPreview 窗口预览"]
    S0 --> S3["披风选择与上传辅助"]
    S3 --> S4["同步到皮肤站 / 本地缓存"]
    S2 --> S5([用户确认应用])
```

---

## 12. 更新检查与通用设置

```mermaid
flowchart TD
    U0([系统维护]) --> U1["SparkleUpdateService 启动检查"]
    U1 --> U2{"有新版本?"}
    U2 -->|是| U3["提示下载更新"]
    U2 -->|否| U4["静默继续"]

    U0 --> U5["SettingsView 通用设置"]
    U5 --> U6["语言 LanguageManager"]
    U5 --> U7["外观 ThemeManager"]
    U5 --> U8["代理 / 下载并发 / 布局"]
    U7 --> U9["preferredColorScheme + NSApp.appearance"]
```

### 主题切换子流程

```mermaid
flowchart TD
    T0([用户切换主题]) --> T1["ThemeManager.themeMode 写入"]
    T1 --> T2["applyAppAppearance NSApp"]
    T1 --> T3["preferredColorScheme 刷新 SwiftUI"]
    T3 --> T4{"模式"}
    T4 -->|浅色/深色| T5["固定 ColorScheme"]
    T4 -->|跟随系统| T6["resolveSystemColorScheme"]
    T6 --> T7["KVO 监听系统外观变化"]
```

---

## 13. 核心数据流（简化）

```mermaid
flowchart LR
    User["用户操作"] --> VM["ViewModel / UseCase"]
    VM --> Mgr["Manager / Service"]
    Mgr --> Persist{"持久化"}
    Persist --> UD["UserDefaults"]
    Persist --> KC["Keychain"]
    Persist --> FS["文件系统"]
    Mgr --> Net["网络 API"]
    Mgr --> UI2["@Published 驱动 UI 刷新"]
```

---

## 14. 部署与运行环境

```mermaid
flowchart TB
    subgraph macOS["macOS 宿主"]
        AppBundle["Swift Craft Launcher.app"]
        SwiftUI["SwiftUI 窗口"]
        AppKit["AppKit Sparkle 等"]
        Child["Java 子进程 Minecraft"]
    end

    AppBundle --> SwiftUI
    AppBundle --> AppKit
    AppBundle --> Child
    Child --> GameDir["游戏工作目录 .profiles"]
```
