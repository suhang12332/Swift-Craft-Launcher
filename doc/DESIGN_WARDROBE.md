# 衣柜功能设计文档

## 1. 概述与目标

**功能名称**：衣柜（Wardrobe）

**目标**：为正版（Microsoft/Mojang）玩家提供「上传历史」与「一键切换」能力：记录玩家在本启动器内上传过的皮肤，并支持从衣柜中快速切换回某一套皮肤，无需重新选择文件。

**价值**：
- 减少重复操作：换过的皮肤可随时切回，不必再找文件。
- 与现有皮肤管理形成互补：当前流程是「选文件 → 上传」，衣柜在此基础上增加「从历史中选一条 → 直接应用」。

---

## 2. 范围与约束

| 项目 | 说明 |
|------|------|
| **适用账号** | 仅**正版用户**（`Player.isOnlineAccount == true`），即具备有效 `AuthCredential`、可调用 Minecraft Services 皮肤 API 的账号。离线账号不展示衣柜入口。 |
| **数据来源** | 仅记录**在本启动器内成功上传过的皮肤**。不拉取 Mojang 侧的历史皮肤列表（Minecraft Profile API 仅返回当前激活皮肤等信息，无完整上传历史）。 |
| **切换语义** | 「切换」= 将衣柜中某条记录的皮肤**再次上传**为当前账号的激活皮肤（复用现有 `PlayerSkinService.uploadSkin` 流程）。 |

---

## 3. 数据模型

### 3.1 衣柜条目（WardrobeEntry）

单条「上传过的皮肤」的本地记录：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` (UUID) | 本地唯一标识，用于删除、去重。 |
| `skinData` | `Data` | PNG 皮肤图片数据（64×64 或 64×32）。 |
| `model` | `PublicSkinInfo.SkinModel` | `classic` / `slim`。 |
| `displayName` | `String?` | 用户可选的备注名（如「圣诞皮肤」）；可选，默认可用上传时间或「皮肤 1」等占位。 |
| `addedAt` | `Date` | 加入衣柜的时间。 |

说明：
- 不依赖远程 URL：切换时用本地 `skinData` 调用现有上传接口即可。
- 若后续需要「仅存 URL + 按需下载」，可再扩展；首版建议以本地 Data 为主，逻辑简单、离线可切换。

### 3.2 衣柜存储范围

- **按玩家维度**：每个玩家（以 `Player.id` / UUID 为准）拥有自己的衣柜列表。
- **存储位置**：应用本地（如 Application Support 下专用目录），不依赖云；格式可为 JSON + 图片存文件，或单一持久化结构（如 SQLite/JSON 内嵌 base64，视实现偏好）。具体路径与格式在实现阶段确定。

### 3.3 去重与上限（可选）

- **去重**：同一玩家下，若本次上传的 `skinData` 与已有某条完全一致（且 model 相同），可选择不重复插入，仅更新 `addedAt` 或忽略。
- **上限**：可设单玩家衣柜条数上限（如 20～50），超出时提示或按时间删除最旧条目，避免无限增长。

---

## 4. 核心流程

### 4.1 添加条目（上传成功后写入衣柜）

- **触发时机**：在现有「上传皮肤」流程**成功**后（即 `PlayerSkinService.uploadSkinAndRefresh` 返回成功之后）。
- **步骤**：
  1. 使用本次上传的 `imageData` 与 `model` 构造 `WardrobeEntry`（生成 `id`，`addedAt = Date()`，`displayName` 可选）。
  2. 可选：与当前玩家衣柜中已有条目做去重（比较 `skinData` + `model`）。
  3. 将新条目追加到当前玩家的衣柜列表并持久化。
- **注意**：仅正版用户且上传成功才写入；上传失败或取消不写入。

### 4.2 切换皮肤（从衣柜应用）

- **输入**：用户选择衣柜中的某一条 `WardrobeEntry`，并确认「应用」。
- **步骤**：
  1. 校验当前选中玩家为正版且 token 有效（可与现有皮肤管理一致）。
  2. 使用该条目的 `skinData` 和 `model` 调用 `PlayerSkinService.uploadSkinAndRefresh(imageData:model:player:)`。
  3. 成功后刷新本地当前皮肤展示、并发送 `PlayerSkinService.playerUpdatedNotification`（与现有逻辑一致）。
  4. 可选：将「当前正在使用的皮肤」在衣柜 UI 中高亮或标记为「当前使用」。
- **错误**：网络失败、token 过期等沿用现有 `PlayerSkinService` 与 `GlobalErrorHandler` 的报错方式。

### 4.3 删除条目

- 用户可从衣柜列表中删除某条记录；仅删除本地数据，不影响 Mojang 端当前激活的皮肤。
- 若需「删除并同时重置当前皮肤」，可再拆为两步或单独按钮（首版可只做「仅删本地记录」）。

### 4.4 与「重置皮肤」的关系

- 现有「重置皮肤」仅调用 Mojang API 清除当前激活皮肤，不涉及衣柜。
- 重置后，当前激活皮肤在衣柜中的对应条目（若存在）仍可保留；用户之后仍可从衣柜再次应用该皮肤。

---

## 5. UI 与入口

### 5.1 入口

- **推荐**：在现有**皮肤管理**界面（如 `SkinToolDetailView` 所在 Sheet）中增加「衣柜」区块或 Tab：
  - 仅当当前选中玩家为正版时显示该区块/Tab。
  - 文案示例：「衣柜」「上传历史」「我的皮肤」等，由产品/国际化决定。

### 5.2 衣柜列表

- 展示当前玩家的所有衣柜条目：缩略图 + 可选备注名 + 添加时间；每条提供「应用」与「删除」操作。
- 可考虑支持简单排序：按添加时间倒序（最新在前）。
- 若当前 Mojang 激活皮肤与某条一致（如通过 URL 或 skinData 比对），可标记为「当前使用」（可选）。

### 5.3 空状态与引导

- 衣柜为空时：提示「上传过的皮肤会出现在这里」，并引导用户先去上传一次皮肤。
- 非正版玩家进入皮肤管理时：不显示衣柜入口，或显示「仅正版账号可使用衣柜」的说明。

### 5.4 可选：编辑备注名

- 支持对某条衣柜条目编辑 `displayName`，便于识别（如「夏季」「活动皮肤」）。

---

## 6. 与现有代码的关系

| 现有组件 | 使用方式 |
|----------|----------|
| `PlayerSkinService.uploadSkin` / `uploadSkinAndRefresh` | 衣柜「切换」时直接调用，传入条目的 `skinData` 与 `model`。 |
| `PlayerSkinService.resetSkin` / `resetSkinAndRefresh` | 不修改；重置皮肤与衣柜独立。 |
| `Player.isOnlineAccount` | 用于控制衣柜入口与添加逻辑是否可用。 |
| `PlayerSkinService.playerUpdatedNotification` | 上传/切换成功后由现有上传流程触发，无需在衣柜层重复发。 |
| `SkinToolDetailView` / 上传流程 | 在上传成功回调中调用「添加条目到衣柜」的新逻辑。 |
| `PlayerDataManager` / `UserProfileStore` | 不存储衣柜数据；衣柜使用独立存储（见 3.2）。 |

---

## 7. 国际化与错误

- **文案**：所有用户可见字符串走 `Localizable.xcstrings`（如 `wardrobe.*`）。
- **错误**：网络、token、校验错误沿用 `GlobalError` 与现有 i18n key，不在衣柜内单独定义一套，仅必要时增加如 `wardrobe.save_failed` 等少量 key。

---

## 8. 实现建议（概要）

1. **模型与存储**：新建 `WardrobeEntry` 与「按玩家 UUID 的衣柜列表」持久化（如 `WardrobeStore` / `WardrobeRepository`）。
2. **服务层**：可新增 `WardrobeService`，负责：添加条目、删除条目、按玩家读取列表；切换时调用现有 `PlayerSkinService.uploadSkinAndRefresh`。
3. **UI**：在皮肤管理内增加衣柜列表视图（SwiftUI），列表项为缩略图 + 操作按钮；上传成功处调用 `WardrobeService.addEntry(...)`。
4. **测试**：覆盖「上传后有一条」「切换成功」「非正版不显示/不写入」「删除仅影响本地」等场景。

---

## 9. 后续可选增强

- 衣柜条目支持「仅存 URL」、首次应用时再下载并上传（节省本地空间）。
- 导出/导入衣柜（备份或跨设备）。
- 与「当前激活皮肤」的同步状态在 UI 上更明显（如高亮、角标）。
- 斗篷（Cape）若未来有类似「历史」需求，可复用同一套「衣柜」概念做扩展。

---

**文档版本**：1.0  
**最后更新**：2025-03-01
