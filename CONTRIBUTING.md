# 贡献指南 📘
  🇨🇳简体中文 | [🇬🇧English](/doc/CONTRIBUTING_en.md)

#### 欢迎你为 SwiftCraftLauncher 贡献！谢谢你愿意参与 🙌。请先看这份指南，可以让我们协作更顺畅，也能让你的贡献更容易被接纳。

### 1. 行为准则 （Code of Conduct）✨

尊重他人：保持友善、建设性、不攻击。

开放与包容：欢迎各种背景的贡献者。

清晰沟通：Issue、PR 描述要尽量清楚，避免误解。

---

### 2. 如何报告问题（Issue）🐞

当你发现 bug 或者有改进建议：

在 GitHub 上的 Issues 里新开一个 issue。

标题要简洁醒目，比如：

“[BUG] 启动时崩溃在 macOS 14.1 – Java 路径未找到”

内容包含：

操作系统版本（macOS + 版本号）

SwiftCraftLauncher 的版本（release 或者 commit hash）

你做了什么 → 期望是什么 → 实际发生什么

如果可以的话，附上 error log 或者截图

---

### 3. 贡献代码（Pull Request）流程 🚀

确保你 Fork 了项目，并把原作者最新 dev 分支同步到你的仓库。

从最新的 dev 分支创建一个功能分支（feature branch）：

dev → feature/你的描述


例如 feature/fix-java-path 或 feature/add-mod-support。

在 feature 分支上做改动。改动内容应专注一件事情，尽量小而明确。

写清楚 commit message：

用英文或者中英文混合明确说明做了什么

用动词开头，比如 “Fix …”, “Add …”, “Improve …” 等

本地测试没问题之后，把分支 push 到你 fork 的仓库。

到 GitHub 上创建 PR，目标库（base repo）是原作者仓库，base 分支是 dev，compare 分支是你的 feature 分支。

在 PR 描述里包含：

为什么要做这个改动

改动是什么

如果可能，有效果截图或者 log

等待 Review，可能会有建议要改的地方，请耐心修改。

---

### 4. 代码风格和质量 🌱

语言是 Swift，UI 用 SwiftUI。请遵守 Swift 的命名规范（CamelCase、清晰的变量／函数名）

注释要合理：公共 API／复杂逻辑最好有注释

遵守已有的项目结构，不要把文件乱放

写测试（如果合适），确保改动没有破坏已有功能

注意处理 edge cases，异常情况不要崩溃

---

### 5. 分支管理规则 🌲

dev 是开发主分支，用于合并所有功能／修复之后再发布／打包

新功能／修复请都基于 dev 分支创建 feature 分支

PR 永远以 dev 为 base 分支提交

---

### 6. 本地开发环境 💻

使用 Xcode（版本 >= 项目要求）

确保本地 Swift 版本符合项目要求

可能要安装对应的 Java 版本（若启动器相关功能依赖）

编译、运行、手动测试功能是否一切正常

---

### 7. 合并与发布 📦

项目维护者会 Review PR，如果通过，会合并到 dev

当 dev 达到一个稳定状态或者准备发布版本时，会创建 release tag

发布版本前会进行测试确认，无重大 BUG

---

### 8. 感谢你！💖

感谢你愿意贡献时间、精力。每一个 issue、每一个 PR、每一点建议都很宝贵。
