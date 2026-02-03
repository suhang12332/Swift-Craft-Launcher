# SwiftCraftLauncher 业务域 + 分层 架构

本文档明确“按业务域 + 分层”的组织方式与依赖方向，便于维护、扩展与测试。

---

## 一、总体结构（业务域 + 分层）

项目按“业务域”拆分，每个业务域内部再按分层组织。通用能力放在 `Common` 中对应的模块。

```
SwiftCraftLauncher/
  Common/
    Models/
    Services/
    Managers/
    Data/
    UseCases/
    Utils/
    State/

  Game/                      # 业务域：游戏实例与启动
    Views/
    ViewModels/
    Models/
    UseCases/
    Services/
    Data/
    Utils/

  Player/                    # 业务域：账号/玩家
    Views/
    ViewModels/
    Models/
    Services/
    Data/
    Utils/

  Resource/                  # 业务域：资源/模组/依赖
    Views/
    ViewModels/
    Models/
    Services/
    Data/
    Utils/

  ModPack/                   # 业务域：模组包导入/导出
    Views/
    ViewModels/
    Models/
    Services/
    Data/
    Utils/
```

## 二、分层与依赖方向（域内一致）

```
┌──────────────────────────────────────────────────────────┐
│  Views (SwiftUI)                                          │
└──────────────────────────────┬───────────────────────────┘
                               │ 仅依赖
                               ▼
┌──────────────────────────────────────────────────────────┐
│  ViewModels / UseCases / State                            │
└──────────────────────────────┬───────────────────────────┘
                               │ 依赖
                               ▼
┌──────────────────────────────────────────────────────────┐
│  Services / Managers / Repositories                       │
└──────────────────────────────┬───────────────────────────┘
                               │ 可选依赖
                               ▼
┌──────────────────────────────────────────────────────────┐
│  Data / Run / Utils / Models                              │
└──────────────────────────────────────────────────────────┘
```

### 规则

1. **业务功能按域归类**：能明确归属业务的代码，必须放入对应域目录（如 `Game/`、`Player/`、`Resource/`、`ModPack/`）。
2. **域内按分层组织**：每个域内使用 `Views / ViewModels / Models / Services / Data / Utils / UseCases` 等子模块。
3. **通用能力下沉到 Common**：跨域复用的能力放到 `Common/*` 对应模块，而不是放到某个业务域里。
4. **Views** 不直接依赖 Run 或具体 Service/Manager；通过 **UseCase** 或 **EnvironmentObject** 获取能力。
5. **ViewModels / UseCases** 依赖 Repositories、Services、Managers；通过协议或注入获取，便于测试与替换。
6. **Run、Utils、Models** 不依赖 Views；与 UI 的交互通过回调、UseCase 或上层传入的依赖完成。
7. **Repositories** 的上下文通过协议注入（如 `WorkingPathProviding`），不直接依赖全局单例。

---

## 三、模块职责（通用与域内一致）

| 模块/类型 | 职责 | 依赖方向 |
|-----------|------|----------|
| **Views** | 展示与用户交互；从 Environment 获取 State、UseCase | → ViewModels / UseCases / State |
| **ViewModels** | 列表/表单逻辑、状态管理、调用用例 | → Services, Repositories, UseCases |
| **UseCases** | 单一业务流程编排（如“启动游戏”“停止游戏”） | → Services, Repositories, Run |
| **Services** | 外部 API、平台 SDK、网络请求 | 被 ViewModels/UseCases 调用 |
| **Repositories / Data** | 持久化、缓存、数据读写 | 被 Services/UseCases 调用 |
| **Managers** | 业务状态/设置管理 | 被 ViewModels/UseCases 调用 |
| **Run** | 进程启动/停止、启动参数构建 | 被 UseCase 调用；不依赖 Views |
| **Utils** | 通用工具、错误处理、路径常量 | 被各层使用；不依赖 Views |
| **Models** | 业务数据结构 | 被各层引用；不依赖 Views |
| **Common/State** | 跨域 UI 状态 | 被 Views 注入与消费 |

---

## 四、关键抽象

- **WorkingPathProviding**：提供当前工作路径与变化通知；由 `GeneralSettingsManager` 实现并注入到 `GameRepository`，实现“工作路径”与“游戏列表”职责分离。
- **GameLaunchUseCase**：对外提供 `launchGame(player:game:)` 与 `stopGame(game:)`；内部使用 `MinecraftLaunchCommand`，UI 只依赖 UseCase，不直接依赖 Run 类型。

---

## 五、实施记录（中期）

- **模块边界文档**：本文档更新为“业务域 + 分层”结构。
- **GameRepository 拆分**：引入 `WorkingPathProviding`，`GameRepository` 通过注入获取当前工作路径，不再直接依赖 `GeneralSettingsManager.shared`。
- **启动逻辑解耦**：新增 `GameLaunchUseCase`，`DetailToolbarView`、`SidebarView` 通过 `@EnvironmentObject` 使用 UseCase，不再直接构造 `MinecraftLaunchCommand`。

---

## 六、GameFeature 目录速览（2026-02 重组后）

```
SwiftCraftLauncher/Features/GameFeature/
  Views/
    AddGame/            # 游戏实例创建、导入、下载流程
    GameDetail/         # 实例详情、资源与依赖管理
    Root/               # MainView / ContentView / DetailView 容器
    Start/              # 启动时的提示/弹窗
  ViewModels/           # GameCreationViewModel, DependencySheetViewModel, ...
  UseCases/             # GameLaunchUseCase 等业务编排
  Data/                 # GameRepository, GameVersionDatabase, ModCacheDatabase, SQLiteDatabase
  Managers/             # GameSettingsManager, GameStatusManager, SelectedGameManager, GameNameValidator
  Utils/                # LocalResourceInstaller 等实例级工具
```

职责划分：

- **Views / ViewModels** 覆盖“创建 / 导入 / 管理 / 展示”全流程。
- **UseCases** 提供统一的启动/停止接口，屏蔽 Run 层实现。
- **Data** 封装实例、版本、缓存等持久化逻辑；依赖 `WorkingPathProviding` 获取上下文。
- **Managers** 管理用户选择、设置、状态同步；通过依赖注入供 ViewModels/UseCases 使用。
- **Utils** 存放与游戏实例强耦合的工具（如本地资源安装器）。

其他域（Player / Resource / ModPack）采用同样的分层约定；通用组件继续放在 `Common/`。

---

*文档生成日期：2026-02-03*
