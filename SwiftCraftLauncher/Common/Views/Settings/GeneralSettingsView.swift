import SwiftUI
import AppKit

public struct GeneralSettingsView: View {
    @StateObject private var generalSettings = GeneralSettingsManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var sparkleUpdateService: SparkleUpdateService
    @State private var showDirectoryPicker = false
    @State private var showingRestartAlert = false
    @State private var previousLanguage: String = ""
    @State private var isCancellingLanguageChange = false
    @State private var selectedLanguage = LanguageManager.shared.selectedLanguage
    @State private var error: GlobalError?

    public init() {}

    public var body: some View {
        Form {
            LabeledContent("settings.language.picker".localized()) {
                Picker("", selection: $selectedLanguage) {
                    ForEach(LanguageManager.shared.languages, id: \.1) { name, code in
                        Text(name).tag(code)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .onChange(of: selectedLanguage) { _, newValue in
                    // 如果是取消操作导致的语言恢复，则不触发重启提示
                    if newValue != LanguageManager.shared.selectedLanguage {
                        showingRestartAlert = true
                    }
                }
                .confirmationDialog(
                    "settings.language.restart.title".localized(),
                    isPresented: $showingRestartAlert,
                    titleVisibility: .visible
                ) {
                    Button("settings.language.restart.confirm".localized(), role: .destructive) {
                        // 在重启前更新 Sparkle 的语言设置
                        sparkleUpdateService.updateSparkleLanguage(selectedLanguage)
                        LanguageManager.shared.selectedLanguage = selectedLanguage
                        restartAppSafely()
                    }
                    .keyboardShortcut(.defaultAction)
                    Button("common.cancel".localized(), role: .cancel) {
                        selectedLanguage = LanguageManager.shared.selectedLanguage
                    }
                } message: {
                    Text("settings.language.restart.message".localized())
                }
            }.labeledContentStyle(.custom).padding(.bottom, 10)

            LabeledContent("settings.theme.picker".localized()) {
                ThemeSelectorView(selectedTheme: $themeManager.themeMode)
                    .fixedSize()
            }.labeledContentStyle(.custom)

            LabeledContent("settings.interface_style.label".localized()) {
                Picker("", selection: $generalSettings.interfaceLayoutStyle) {
                    ForEach(InterfaceLayoutStyle.allCases, id: \.self) { style in
                        Text(style.localizedName).tag(style)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }.labeledContentStyle(.custom).padding(.bottom, 10)

            LabeledContent("settings.launcher_working_directory".localized()) {
                DirectorySettingRow(
                    title: "settings.launcher_working_directory".localized(),
                    path: generalSettings.launcherWorkingDirectory.isEmpty ? AppPaths.launcherSupportDirectory.path : generalSettings.launcherWorkingDirectory,
                    description: "settings.working_directory.description".localized(),
                    onChoose: { showDirectoryPicker = true },
                    onReset: {
                        resetWorkingDirectorySafely()
                    }
                ).fixedSize()
                    .fileImporter(isPresented: $showDirectoryPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                        handleDirectoryImport(result)
                    }
            }.labeledContentStyle(.custom(alignment: .firstTextBaseline))

            LabeledContent("settings.concurrent_downloads.label".localized()) {
                HStack {
                    Slider(
                        value: Binding(
                            get: {
                                Double(generalSettings.concurrentDownloads)
                            },
                            set: {
                                generalSettings.concurrentDownloads = Int(
                                    $0
                                )
                            }
                        ),
                        in: 1...64
                    ).controlSize(.mini)
                        .animation(.easeOut(duration: 0.5), value: generalSettings.concurrentDownloads)
                    // 当前内存值显示（右对齐，固定宽度）
                    Text("\(generalSettings.concurrentDownloads)").font(
                        .subheadline
                    )
                    .foregroundColor(.secondary)
                    .fixedSize()
                }.frame(width: 200)
                    .gridColumnAlignment(.leading)
                    .labelsHidden()
            }.labeledContentStyle(.custom)
            LabeledContent("settings.github_proxy.label".localized()) {
                VStack(alignment: .leading) {
                    HStack {
                        Toggle(
                            "",
                            isOn: $generalSettings.enableGitHubProxy
                        )
                        .labelsHidden()
                        Text("settings.github_proxy.enable".localized())
                            .font(.callout)
                            .foregroundColor(.primary)
                    }
                    HStack(spacing: 8) {
                        TextField(
                            "",
                            text: $generalSettings.gitProxyURL
                        )
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .focusable(false)
                        .disabled(!generalSettings.enableGitHubProxy)
                        Button("settings.github_proxy.reset_default".localized()) {
                            generalSettings.gitProxyURL = "https://gh-proxy.com"
                        }
                        .disabled(!generalSettings.enableGitHubProxy)
                        InfoIconWithPopover(text: "settings.github_proxy.description".localized())
                    }
                }
            }.labeledContentStyle(.custom(alignment: .firstTextBaseline)).padding(.top, 10)
        }
        .globalErrorHandler()
        .alert(
            "error.notification.validation.title".localized(),
            isPresented: .constant(error != nil && error?.level == .popup)
        ) {
            Button("common.close".localized()) {
                error = nil
            }
        } message: {
            if let error = error {
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - Private Methods

    /// 安全地重置工作目录
    private func resetWorkingDirectorySafely() {
        do {
            guard let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent(Bundle.main.appName) else {
                throw GlobalError.configuration(
                    chineseMessage: "无法获取应用支持目录",
                    i18nKey: "error.configuration.app_support_directory_not_found",
                    level: .popup
                )
            }

            // 确保目录存在
            try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)

            generalSettings.launcherWorkingDirectory = supportDir.path

            Logger.shared.info("工作目录已重置为: \(supportDir.path)")
        } catch {
            let globalError = GlobalError.from(error)
            GlobalErrorHandler.shared.handle(globalError)
            self.error = globalError
        }
    }

    /// 处理目录导入结果
    private func handleDirectoryImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                do {
                    // 验证目录是否可访问
                    let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .isReadableKey])
                    guard resourceValues.isDirectory == true, resourceValues.isReadable == true else {
                        throw GlobalError.fileSystem(
                            chineseMessage: "选择的路径不是可读的目录",
                            i18nKey: "error.filesystem.invalid_directory_selected",
                            level: .notification
                        )
                    }

                    generalSettings.launcherWorkingDirectory = url.path
                    // GameRepository 观察者会自动重新加载，无需手动 loadGames

                    Logger.shared.info("工作目录已设置为: \(url.path)")
                } catch {
                    let globalError = GlobalError.from(error)
                    GlobalErrorHandler.shared.handle(globalError)
                    self.error = globalError
                }
            }
        case .failure(let error):
            let globalError = GlobalError.fileSystem(
                chineseMessage: "选择目录失败: \(error.localizedDescription)",
                i18nKey: "error.filesystem.directory_selection_failed",
                level: .notification
            )
            GlobalErrorHandler.shared.handle(globalError)
            self.error = globalError
        }
    }

    /// 安全地重启应用
    private func restartAppSafely() {
        do {
            try restartApp()
        } catch {
            let globalError = GlobalError.from(error)
            GlobalErrorHandler.shared.handle(globalError)
            self.error = globalError
        }
    }
}

/// 重启应用
/// - Throws: GlobalError 当重启失败时
private func restartApp() throws {
    guard let appURL = Bundle.main.bundleURL as URL? else {
        throw GlobalError.configuration(
            chineseMessage: "无法获取应用路径",
            i18nKey: "error.configuration.app_path_not_found",
            level: .popup
        )
    }

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    task.arguments = [appURL.path]

    try task.run()

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Theme Selector View
struct ThemeSelectorView: View {
    @Binding var selectedTheme: ThemeMode

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ThemeMode.allCases, id: \.self) { theme in
                ThemeOptionView(
                    theme: theme,
                    isSelected: selectedTheme == theme
                ) {
                    selectedTheme = theme
                }
            }
        }
    }
}

// MARK: - Theme Option View
struct ThemeOptionView: View {
    let theme: ThemeMode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // 主题图标
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: isSelected ? 3 : 0)
                    .frame(width: 61, height: 41)

                // 窗口图标内容
                ThemeWindowIcon(theme: theme)
                    .frame(width: 60, height: 40)
            }

            // 主题标签
            Text(theme.localizedName)
                .font(.caption)
                .foregroundColor(isSelected ? .primary : .secondary)
        }
        .onTapGesture {
            onTap()
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Theme Window Icon
struct ThemeWindowIcon: View {
    let theme: ThemeMode

    var body: some View {
        Image(iconName)
            .resizable()
            .frame(width: 60, height: 40)
            .cornerRadius(6)
    }

    private var iconName: String {
        let isSystem26 = ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26
        switch theme {
        case .system:
            return isSystem26 ? "AppearanceAuto_Normal_Normal" : "AppearanceAuto_Normal"
        case .light:
            return isSystem26 ? "AppearanceLight_Normal_Normal" : "AppearanceLight_Normal"
        case .dark:
            return isSystem26 ? "AppearanceDark_Normal_Normal" : "AppearanceDark_Normal"
        }
    }
}

#Preview {
    GeneralSettingsView()
}
