# 整合包导出逻辑梳理

## 整体架构

导出功能分为三层：
1. **视图层（ModPackExportSheet）** - UI 展示和用户交互
2. **视图模型层（ModPackExportViewModel）** - 状态管理和业务逻辑
3. **导出器层（ModPackExporter）** - 实际的导出操作

---

## 状态流转

### ViewModel 状态枚举

```swift
enum ExportState {
    case idle          // 空闲状态，显示表单
    case exporting     // 正在导出，显示进度
    case completed     // 导出完成，等待保存，显示进度（100%）
}
```

### 关键状态变量

- `exportState`: 导出状态（idle/exporting/completed）
- `tempExportPath`: 临时文件路径（导出完成后设置）
- `hasShownSaveDialog`: 是否已显示保存对话框（防止重复自动弹出）
- `shouldShowSaveDialog`: 计算属性 = `tempExportPath != nil && !hasShownSaveDialog`

---

## 完整流程

### 1. 初始化阶段

**触发点**: Sheet 显示时（`onAppear`）

```
用户打开导出 Sheet
    ↓
initializeDefaults()
    ↓
如果 modPackName 为空，设置为 gameInfo.gameName
    ↓
显示表单（exportState = .idle）
```

### 2. 开始导出

**触发点**: 用户点击"导出"按钮

```
用户点击导出按钮
    ↓
检查：如果 exportState == .completed 且 tempExportPath 存在
    ├─ 是 → handleExportCompleted() → 重新显示保存对话框
    └─ 否 → viewModel.startExport(gameInfo)
            ↓
        startExport() 执行：
        1. 重置状态（exportState = .exporting）
        2. 创建临时文件路径
        3. 启动异步导出任务
            ↓
        ModPackExporter.exportModPack() 执行：
        1. 准备临时目录
        2. 扫描资源文件（显示扫描进度条）
        3. 识别资源文件（更新扫描进度）
        4. 复制文件到 overrides 目录（显示复制进度条）
        5. 生成 modrinth.index.json
        6. 打包为 .mrpack 文件
        7. 进度条显示 100%
            ↓
        导出完成回调：
        ├─ 成功 → exportState = .completed, tempExportPath = 输出路径
        └─ 失败 → exportState = .idle, exportError = 错误信息
```

### 3. 自动显示保存对话框（首次完成）

**触发点**: `onChange(of: viewModel.shouldShowSaveDialog)`

```
导出完成，tempExportPath 被设置
    ↓
shouldShowSaveDialog 变为 true（因为 hasShownSaveDialog = false）
    ↓
onChange 触发
    ↓
handleExportCompleted(tempFilePath)
    ↓
1. markSaveDialogShown() → hasShownSaveDialog = true
2. 读取临时文件数据
3. 创建 ModPackDocument
4. 设置 exportDocument
5. DispatchQueue.main.async { isExporting = true }
    ↓
fileExporter 显示系统保存对话框
```

### 4. 文件保存处理

**触发点**: fileExporter 回调

```
用户选择保存位置
    ↓
fileExporter 回调触发
    ├─ .success(url):
    │   ├─ Logger 记录成功
    │   ├─ viewModel.handleSaveSuccess()
    │   │   ├─ cleanupTempFile() → 删除临时文件
    │   │   ├─ hasShownSaveDialog = false
    │   │   ├─ exportState = .idle
    │   │   └─ 重置进度
    │   └─ dismiss() → 关闭 Sheet
    │
    └─ .failure(error):
        ├─ Logger 记录错误
        ├─ viewModel.handleSaveFailure(error)
        │   ├─ saveError = error
        │   ├─ cleanupTempFile()
        │   └─ hasShownSaveDialog = false
        └─ 显示错误 Alert
```

### 5. 用户取消 fileExporter

**触发点**: `onChange(of: isExporting)`

```
用户取消文件保存对话框
    ↓
isExporting 从 true 变为 false
    ↓
onChange(of: isExporting) 触发
    ↓
检查：oldValue == true && newValue == false && exportDocument != nil
    ↓
只清除 exportDocument = nil
（不重置 hasShownSaveDialog，避免立即再次触发）
    ↓
shouldShowSaveDialog 保持为 false
（因为 hasShownSaveDialog = true）
    ↓
不会自动弹出窗口
```

### 6. 用户再次点击导出按钮（已完成状态）

**触发点**: 用户点击导出按钮（exportState == .completed）

```
用户点击导出按钮
    ↓
检查：exportState == .completed && tempExportPath 存在
    ↓
handleExportCompleted(tempFilePath)
    ↓
检查 shouldShowSaveDialog（此时为 false，因为 hasShownSaveDialog = true）
    ↓
不调用 markSaveDialogShown()
    ↓
直接读取文件并显示 fileExporter
    ↓
用户可以重新选择保存位置
```

### 7. 取消导出任务

**触发点**: 用户点击取消按钮（导出中）

```
用户点击取消按钮
    ↓
如果 viewModel.isExporting == true
    ↓
viewModel.cancelExport()
    ├─ exportTask?.cancel() → 取消异步任务
    ├─ cleanupTempFile() → 删除临时文件
    ├─ exportState = .idle
    └─ 重置所有状态
    ↓
dismiss() → 关闭 Sheet
```

### 8. Sheet 关闭清理

**触发点**: `onDisappear`

```
Sheet 关闭
    ↓
viewModel.cleanupAllData()
    ├─ exportTask?.cancel()
    ├─ cleanupTempFile()
    ├─ cleanupTempDirectories()
    └─ 重置所有状态和属性
```

---

## 关键设计点

### 1. 防止重复弹出保存对话框

- 使用 `hasShownSaveDialog` 标志
- `shouldShowSaveDialog` 只在首次导出完成时为 true
- 自动触发时调用 `markSaveDialogShown()` 标记已显示
- 手动触发（按钮点击）时不标记，允许重新显示

### 2. 状态同步

- View 层使用 `@State` 管理 UI 状态（`isExporting`, `exportDocument`）
- ViewModel 层使用 `@Published` 管理业务状态（`exportState`, `tempExportPath`）
- 通过 `onChange` 监听状态变化，触发相应操作

### 3. 临时文件管理

- 导出到系统临时目录
- 成功保存后删除临时文件（fileExporter 会复制文件）
- Sheet 关闭时清理所有临时文件
- 取消时也清理临时文件

### 4. 进度显示

- 支持多个进度条（扫描进度、复制进度）
- 进度通过回调实时更新
- 完成后进度条显示 100%，保留在 UI 上

### 5. 错误处理

- 导出失败：显示错误视图，状态回到 idle
- 保存失败：显示错误 Alert，清理临时文件
- 所有错误都通过 Logger 记录

---

## 状态图

```
[idle]
  │ 用户点击导出按钮
  ↓
[exporting] ──→ 用户点击取消 ──→ [idle]
  │
  │ 导出完成（成功）
  ↓
[completed] ──→ 自动触发 ──→ [显示 fileExporter]
  │                              │
  │ 用户点击导出按钮（已完成的文件）│ 用户保存成功
  └──────────────────────────────→ [idle] → dismiss()
  
  │ 用户取消 fileExporter
  ↓
[completed] （等待用户再次操作）
```

---

## 文件组织

```
ModPackExport/
├── ModPackExporter.swift          # 核心导出逻辑
├── ResourceScanner.swift           # 资源扫描
├── ResourceProcessor.swift         # 资源处理
├── ConfigFileCopier.swift          # 配置文件复制
├── ModrinthIndexBuilder.swift      # 索引文件生成
└── ModPackArchiver.swift           # 打包为 .mrpack

Views/ModPackExport/
└── ModPackExportSheet.swift        # 导出 Sheet 视图

ViewModels/
└── ModPackExportViewModel.swift    # 导出视图模型
```


