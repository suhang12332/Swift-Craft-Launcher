# GameFeature 文件迁移清单

本清单对应计划中的「classify-game-files」，列出所有与“游戏创建 / 下载 / 导入 / 启动 / 增删改查”紧密相关、需要迁往 `SwiftCraftLauncher/Features/GameFeature` 业务域的代码。之后的步骤将按此映射进行目录重组。

## 1. Views

| 原路径 | 说明 | 目标 GameFeature 子目录 |
| --- | --- | --- |
| `SwiftCraftLauncher/Views/AddGame/CustomVersionPicker.swift` | 版本选择子视图 | `Views/AddGame/CustomVersionPicker.swift` |
| `SwiftCraftLauncher/Views/AddGame/DownloadProgressRow.swift` | 下载进度行 | `Views/AddGame/DownloadProgressRow.swift` |
| `SwiftCraftLauncher/Views/AddGame/DownloadProgressSection.swift` | 下载进度列表 | `Views/AddGame/DownloadProgressSection.swift` |
| `SwiftCraftLauncher/Views/AddGame/FormSection.swift` | 通用表单分区 | `Views/AddGame/FormSection.swift` |
| `SwiftCraftLauncher/Views/AddGame/GameCreationView.swift` | 游戏创建表单入口 | `Views/AddGame/GameCreationView.swift` |
| `SwiftCraftLauncher/Views/AddGame/GameFormProtocols.swift` | 创建表单协议 | `Views/AddGame/GameFormProtocols.swift` |
| `SwiftCraftLauncher/Views/AddGame/GameFormView.swift` | 创建表单视图 | `Views/AddGame/GameFormView.swift` |
| `SwiftCraftLauncher/Views/AddGame/GameFormViewExtensions.swift` | 创建表单扩展 | `Views/AddGame/GameFormViewExtensions.swift` |
| `SwiftCraftLauncher/Views/AddGame/LauncherImportView.swift` | 其他启动器导入入口 | `Views/AddGame/LauncherImportView.swift` |
| `SwiftCraftLauncher/Views/GameDetail/*` (15 个文件) | 游戏详情页、资源管理、依赖管理 | `Views/GameDetail/*` |
| `SwiftCraftLauncher/Views/DetailView.swift` | 包含游戏详情主体 | `Views/Detail/DetailView.swift` |
| `SwiftCraftLauncher/Views/ContentView.swift` | 包含实例列表与入口 | `Views/Root/ContentView.swift` |
| `SwiftCraftLauncher/Views/MainView.swift` | 启动后主容器，含游戏导航 | `Views/Root/MainView.swift` |
| `SwiftCraftLauncher/Views/Start/StartupInfoSheetView.swift` | 游戏启动提示 | `Views/Start/StartupInfoSheetView.swift` |

> 备注：`DetailToolbarView`、`SidebarView` 等仍在 `Common/Views/`，但若后续需要更强边界，可在第二阶段迁入 GameFeature。

## 2. ViewModels & Stores

| 原路径 | 说明 | 目标目录 |
| --- | --- | --- |
| `SwiftCraftLauncher/ViewModels/BaseGameFormViewModel.swift` | 创建视图基类 | `ViewModels/BaseGameFormViewModel.swift` |
| `SwiftCraftLauncher/ViewModels/GameCreationViewModel.swift` | 游戏创建逻辑 | `ViewModels/GameCreationViewModel.swift` |
| `SwiftCraftLauncher/ViewModels/LauncherImportViewModel.swift` | 启动器导入逻辑 | `ViewModels/LauncherImportViewModel.swift` |
| `SwiftCraftLauncher/ViewModels/DependencySheetViewModel.swift` | 依赖管理 | `ViewModels/DependencySheetViewModel.swift` |
| `SwiftCraftLauncher/ViewModels/CategoryContentViewModel.swift` | 分类视图（聚焦游戏实例） | `ViewModels/CategoryContentViewModel.swift` |

## 3. UseCases

| 原路径 | 说明 | 目标目录 |
| --- | --- | --- |
| `SwiftCraftLauncher/Common/UseCases/GameLaunchUseCase.swift` | 游戏启动 / 停止 | `UseCases/GameLaunchUseCase.swift` |

## 4. Data / Repository / Database

| 原路径 | 说明 | 目标目录 |
| --- | --- | --- |
| `SwiftCraftLauncher/Common/Data/GameRepository.swift` | 游戏实例 CRUD | `Data/GameRepository.swift` |
| `SwiftCraftLauncher/Common/Data/GameVersionDatabase.swift` | 版本数据库 | `Data/GameVersionDatabase.swift` |
| `SwiftCraftLauncher/Common/Data/ModCacheDatabase.swift` | 模组缓存（与游戏实例绑定） | `Data/ModCacheDatabase.swift` |
| `SwiftCraftLauncher/Common/Data/SQLiteDatabase.swift` | 数据库基础设施（若只被游戏模块使用，可迁入；否则保持 Common） |
| `SwiftCraftLauncher/Common/Data/WorkingPathProviding.swift` | 工作路径协议（若只被 GameRepository 消费，可同步迁移） |

## 5. Managers

| 原路径 | 说明 | 目标目录 |
| --- | --- | --- |
| `SwiftCraftLauncher/Common/Managers/GameSettingsManager.swift` | 游戏设置 | `Managers/GameSettingsManager.swift` |
| `SwiftCraftLauncher/Common/Managers/GameStatusManager.swift` | 游戏状态 / 运行信息 | `Managers/GameStatusManager.swift` |
| `SwiftCraftLauncher/Common/Managers/GameNameValidator.swift` | 名称校验 | `Managers/GameNameValidator.swift` |
| `SwiftCraftLauncher/Common/Managers/SelectedGameManager.swift` | 当前游戏实例 | `Managers/SelectedGameManager.swift` |
| `SwiftCraftLauncher/Common/Managers/JavaManager.swift` | Java 运行时（若未来拆到独立 JavaFeature，可暂时保留在 Common） |

## 6. Utils & Helpers

| 原路径 | 说明 | 目标目录 |
| --- | --- | --- |
| `SwiftCraftLauncher/Common/Utils/LocalResourceInstaller.swift` | 本地资源安装（与 GameDetail 绑定） | `Utils/LocalResourceInstaller.swift` |
| `SwiftCraftLauncher/Common/Utils/GameResourceHandler.swift`（位于 `Views/GameDetail/` 内） | 资源处理 | `Utils/GameResourceHandler.swift` |
| `SwiftCraftLauncher/Common/Utils/DownloadManager.swift`（如与全局共用，可保留） | - | - |

## 7. Services (若仅供 Game 使用)

| 原路径 | 说明 | 备注 |
| --- | --- | --- |
| `SwiftCraftLauncher/Services/ModLoaderHandler.swift` + 各 Loader Service | 多业务共享，暂留 Services/，后续评估 |
| `SwiftCraftLauncher/Services/CurseForgeService.swift`, `ModrinthService.swift` | 资源域共用，暂不迁 |

## 8. 需要检查的场景

- `SwiftCraftLauncherApp.swift` / `MainView.swift` / `DetailView.swift` 是否对 GameUseCase 或 Manager 有直接引用，迁移后需更新导入路径。
- `Common/Views/DetailToolbarView.swift`、`Common/Views/ContentToolbarView.swift` 中的游戏操作按钮，如依赖 `GameLaunchUseCase`，需调整 import。
- 任何引用 `Views/AddGame/*` 或 `GameCreationViewModel` 的预览 / Feature Flag 文件。

完成本清单后，即可进入下一 Todo：创建 `Features/GameFeature` 目录并迁移上述文件。
