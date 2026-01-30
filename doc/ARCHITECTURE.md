# SwiftCraftLauncher 模块边界与依赖方向

本文档明确中期重构后的模块边界与依赖方向，便于维护与测试。

---

## 一、分层与依赖方向

```
┌─────────────────────────────────────────────────────────────────┐
│  Views (SwiftUI)                                                 │
│  MainView, DetailView, ContentView, DetailToolbarView, SidebarView│
└───────────────────────────┬─────────────────────────────────────┘
                            │ 仅依赖
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  ViewModels / UseCases / Coordinators                            │
│  PlayerListViewModel, ResourceFilterState, ResourceDetailState   │
│  GameLaunchUseCase（启动/停止游戏）                               │
└───────────────────────────┬─────────────────────────────────────┘
                            │ 依赖
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  Repositories / Services / Managers                              │
│  GameRepository, ModrinthService, GameStatusManager, ...          │
└───────────────────────────┬─────────────────────────────────────┘
                            │ 可选依赖
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  Data / Run / Utils                                              │
│  GameVersionDatabase, MinecraftLaunchCommand, AppPaths, ...      │
└─────────────────────────────────────────────────────────────────┘
```

### 规则

1. **Views** 不直接依赖 Run 模块（如 `MinecraftLaunchCommand`）、不直接依赖具体 Service/Manager 实现；通过 **UseCase** 或 **EnvironmentObject** 获取能力。
2. **ViewModels / UseCases** 依赖 Repositories、Services、Managers；通过协议或注入获取，便于测试与替换。
3. **Run、Utils** 不依赖 Views；与 UI 的交互通过回调、UseCase 或上层传入的依赖完成。
4. **Repositories** 的“工作路径”“当前选中”等上下文通过**协议注入**（如 `WorkingPathProviding`），不直接依赖 `GeneralSettingsManager.shared` 等单例。

---

## 二、模块职责

| 模块/类型 | 职责 | 依赖方向 |
|-----------|------|----------|
| **Views** | 展示与用户交互；从 Environment 获取 State、Repository、UseCase | → ViewModels / UseCases / State |
| **ViewModels** | 列表/表单逻辑、远程数据加载 | → Services, Repositories |
| **UseCases** | 单一业务流程（如“启动游戏”“停止游戏”） | → Run 内部实现、Repository（如需更新状态） |
| **GameRepository** | 按工作路径的游戏列表 CRUD、内存缓存、与 DB 同步 | ← WorkingPathProviding 注入；→ GameVersionDatabase, AppPaths |
| **Run** | 进程启动/停止、认证参数替换、进程管理 | 被 UseCase 调用；不依赖 Views |
| **Utils** | 通用工具、错误处理、路径常量 | 被各层使用；不依赖 Views |
| **Common/State** | 筛选、导航、选中项等 UI 状态 | 被 Views 注入与消费 |

---

## 三、关键抽象

- **WorkingPathProviding**：提供当前工作路径与变化通知；由 `GeneralSettingsManager` 实现并注入到 `GameRepository`，实现“工作路径”与“游戏列表”职责分离。
- **GameLaunchUseCase**：对外提供 `launchGame(player:game:)` 与 `stopGame(game:)`；内部使用 `MinecraftLaunchCommand`，UI 只依赖 UseCase，不直接依赖 Run 类型。

---

## 四、实施记录（中期）

- **模块边界文档**：本文档。
- **GameRepository 拆分**：引入 `WorkingPathProviding`，`GameRepository` 通过注入获取当前工作路径，不再直接依赖 `GeneralSettingsManager.shared`。
- **启动逻辑解耦**：新增 `GameLaunchUseCase`，`DetailToolbarView`、`SidebarView` 通过 `@EnvironmentObject` 使用 UseCase，不再直接构造 `MinecraftLaunchCommand`。

---

*文档生成日期：2025-01-30*
