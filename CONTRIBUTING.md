# Contributing Guide

English | [简体中文](doc/CONTRIBUTING.md) | [繁體中文](doc/CONTRIBUTING_zh-TW.md)

Welcome to **Swift Craft Launcher**! Thank you for wanting to contribute. Please read this guide first — it helps us collaborate smoothly and makes it easier for your contributions to be accepted.

### 1. Code of Conduct

Respect others: stay kind, constructive, and non-confrontational.

Open and inclusive: contributors from all backgrounds are welcome.

Clear communication: keep issue and PR descriptions as clear as possible to avoid misunderstandings.

---

### 2. Reporting Issues

When you find a bug or have a suggestion for improvement:

Open a new issue on GitHub.

Use a concise, descriptive title, for example:

"[BUG] Crash on launch on macOS 14.1 – Java path not found"

Include:

OS version (macOS + version number)

Swift Craft Launcher version (release or commit hash)

What you did → what you expected → what actually happened

Error logs or screenshots, if possible

---

### 3. Contributing Code (Pull Request) Workflow

Make sure you have forked the project and synced the latest `dev` branch from the upstream repo into your fork.

Create a feature branch from the latest `dev`:

```
dev → feature/your-description
```

For example: `feature/fix-java-path` or `feature/add-mod-support`.

Make your changes on the feature branch. Keep each change focused on one thing — small and well-defined.

Write clear commit messages:

Explain clearly what you did, in English or a mix of Chinese and English

Start with a verb, such as "Fix …", "Add …", "Improve …", etc.

After local testing passes, push the branch to your fork.

Open a PR on GitHub: base repository is the upstream repo, base branch is `dev`, compare branch is your feature branch.

In the PR description, include:

Why this change is needed

What changed

Screenshots or logs, if applicable

Wait for review. Maintainers may suggest changes — please address feedback patiently.

---

### 4. Code Style and Quality

This project uses [SwiftLint](https://github.com/realm/SwiftLint) for code style checking. Please make sure your code passes lint before submitting.

#### 4.1 Running SwiftLint Locally

```bash
# Install (if not already installed)
brew install swiftlint

# Check all files
swiftformat . --swift-version 6.1

# Check only modified files (recommended, faster)
git diff --cached --name-only | grep '\.swift$' | xargs swiftformat
```

Full configuration is in `.swiftlint.yml` at the project root.

#### 4.3 Style Guidelines

- Language is Swift; UI uses SwiftUI. Follow Swift naming conventions (CamelCase, clear variable/function names)
- Add comments where appropriate: public APIs and complex logic should ideally be documented
- Follow the existing project structure — do not place files arbitrarily
- Write tests when appropriate, and make sure your changes do not break existing behavior
- Handle edge cases; avoid crashing on unexpected conditions
- If you must violate a rule, add `// swiftlint:disable:next <rule_name>` above the line and re-enable it afterwards

---

### 5. CI Requirements

All pull requests must pass the CI pipeline before merging. The CI runs the following checks:

- **SwiftLint**: Code must pass `swiftlint lint --strict` with no violations
- **SwiftFormat**: Code must pass `swiftformat . --swift-version 6.1` formatting check
- **Localization**: All localization strings must be complete across supported languages
- **Unit Tests**: All unit tests must pass

You can run these checks locally before pushing:

```bash
# SwiftLint
swiftlint lint --strict

# SwiftFormat
swiftformat . --swift-version 6.1

# Unit tests
xcodebuild test \
  -project SwiftCraftLauncher.xcodeproj \
  -scheme SwiftCraftLauncher \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO
```

---

### 6. Branching Rules

`dev` is the main development branch. Features and fixes are merged here before release/packaging.

Create feature branches for new work and fixes from `dev`.

Always open PRs with `dev` as the base branch.

---

### 7. Local Development Environment

Use Xcode (version >= project requirement).

Ensure your local Swift version meets project requirements.

You may need to install the appropriate Java version (if launcher-related features depend on it).

Build, run, and manually test that everything works as expected.

### 7.1 Running Unit Tests

```bash
xcodebuild test \
  -project SwiftCraftLauncher.xcodeproj \
  -scheme SwiftCraftLauncher \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO
```

Or use **Product → Test** (`⌘U`) in Xcode.
---

### 8. Merging and Releases

Maintainers will review PRs. If approved, changes are merged into `dev`.

When `dev` reaches a stable state or a release is planned, a release tag is created.

Before a release, testing is performed to confirm there are no major bugs.

---

### 9. Thank You!

Thank you for contributing your time and effort. Every issue, every PR, and every suggestion is valuable.
