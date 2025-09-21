# Contributing Guide 📘
  [🇨🇳简体中文](../CONTRIBUTING.md) | 🇬🇧English

Welcome to **SwiftCraftLauncher**! We’re so glad you’re here 🙌. This guide will help you contribute effectively and ensure your work is smoothly integrated.

---

## 1. Code of Conduct ✨

* **Be respectful**: stay kind, constructive, and professional.
* **Inclusive**: all backgrounds and skill levels are welcome.
* **Clear communication**: describe issues and PRs in a way others can easily understand.

---

## 2. Reporting Issues 🐞

When you find a bug or have a suggestion:

1. Open a new issue on GitHub.
2. Use a clear title, e.g.:

   > “\[BUG] Crash on macOS 14.1 – Java path not found”
3. Include:

   * OS version (e.g. macOS 14.1)
   * SwiftCraftLauncher version (release or commit hash)
   * Steps to reproduce → Expected behavior → Actual behavior
   * Logs, screenshots, or crash reports if available

---

## 3. Submitting Code (Pull Requests) 🚀

1. **Fork** the repository and sync your fork with the latest `dev` branch.
2. **Create a feature branch** from `dev`:

   ```
   dev → feature/short-description
   ```

   Example: `feature/fix-java-path` or `feature/add-mod-support`
3. Make your changes in that branch. Keep changes focused and small.
4. Write clear commit messages:

   * Start with a verb: “Fix …”, “Add …”, “Improve …”
   * Example: `Fix Java detection on macOS`
5. Test locally to ensure nothing is broken.
6. Push the branch to your fork.
7. Open a **Pull Request**:

   * **Base repository**: original SwiftCraftLauncher repo
   * **Base branch**: `dev`
   * **Compare branch**: your feature branch
8. In your PR description, include:

   * Motivation: why this change is needed
   * Summary: what has changed
   * Screenshots/logs if relevant

---

## 4. Code Style & Quality 🌱

* Language: **Swift** with **SwiftUI**
* Follow Swift naming conventions (CamelCase, clear identifiers)
* Add comments for public APIs or complex logic
* Respect project structure (don’t scatter files randomly)
* Write tests when appropriate
* Handle edge cases gracefully (avoid crashes)

---

## 5. Branching Rules 🌲

* `dev`: the main development branch (all features merge here)
* Always create feature branches from `dev`
* All PRs should target `dev` as the base branch

---

## 6. Local Development Setup 💻

* Use the latest stable **Xcode** (version specified by project)
* Ensure your Swift version matches project requirements
* Install the required **Java runtime** if needed (for Minecraft launching features)
* Build, run, and test before submitting your contribution

---

## 7. Merging & Releases 📦

* Maintainers will review PRs before merging into `dev`
* Stable versions are tagged and released from `dev`
* Releases are tested to confirm no major bugs remain

---

## 8. Thank You! 💖

Every issue, PR, or suggestion makes this project better.
We deeply appreciate your time and effort in contributing.
