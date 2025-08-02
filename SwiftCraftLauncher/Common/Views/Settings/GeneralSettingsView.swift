import SwiftUI

public struct GeneralSettingsView: View {
    @ObservedObject private var general = GeneralSettingsManager.shared
    @ObservedObject private var gameSettings = GameSettingsManager.shared
    @EnvironmentObject private var gameRepository: GameRepository
    @State private var showDirectoryPicker = false
    @State private var showingRestartAlert = false
    @State private var previousLanguage: String = ""
    @State private var isCancellingLanguageChange = false
    @State private var selectedLanguage = LanguageManager.shared.selectedLanguage
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    public init() {}
    
    public var body: some View {
        Form {
            VStack(alignment: .leading) {
                Section {
                    Picker("settings.language.picker".localized(), selection: $selectedLanguage) {
                        ForEach(LanguageManager.shared.languages, id: \.1) { name, code in
                            Text(name).tag(code)
                        }
                    }
                    .onChange(of: selectedLanguage) { oldValue, newValue in
                        // 如果是取消操作导致的语言恢复，则不触发重启提示
                        if newValue != LanguageManager.shared.selectedLanguage {
                            showingRestartAlert = true
                        }
                    }.confirmationDialog(
                        "settings.language.restart.title".localized(),
                        isPresented: $showingRestartAlert,
                        titleVisibility: .visible
                    ) {
                        Button("settings.language.restart.confirm".localized(), role: .destructive) {
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
                    Picker("settings.theme.picker".localized(), selection: $general.themeMode) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.localizedName).tag(mode)
                        }
                    }
                }
            }
            .padding(.bottom, 20) // 只控制Section之间的垂直间距
            
            Section {
                LabeledContent {
                    DirectorySettingRow(
                        title: "settings.launcher_working_directory".localized(),
                        path: general.launcherWorkingDirectory.isEmpty ? (AppPaths.launcherSupportDirectory?.path ?? "") : general.launcherWorkingDirectory,
                        description: "settings.working_directory.description".localized(),
                        onChoose: { showDirectoryPicker = true },
                        onReset: {
                            resetWorkingDirectorySafely()
                        }
                    )
                } label: {
                    Text("settings.launcher_working_directory".localized())
                }
                .fixedSize()
                .fileImporter(isPresented: $showDirectoryPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                    handleDirectoryImport(result)
                }
            }
            .padding(.bottom, 20) // 只控制Section之间的垂直间距
            Section {
                LabeledContent {
                    HStack {
                        Slider(
                            value: Binding(
                                get: {
                                    Double(gameSettings.concurrentDownloads)
                                },
                                set: {
                                    gameSettings.concurrentDownloads = Int(
                                        $0
                                    )
                                }
                            ),
                            in: 1...20,
                            label: { EmptyView() },
                            minimumValueLabel: { EmptyView() },
                            maximumValueLabel: { EmptyView() }
                        ).controlSize(.mini).frame(width: 200)
                        .animation(.easeOut(duration: 0.5), value: gameSettings.concurrentDownloads)
                        // 当前内存值显示（右对齐，固定宽度）
                        Text("\(gameSettings.concurrentDownloads)").font(
                            .subheadline
                        ).foregroundColor(.secondary).fixedSize()
                    }
                } label: {
                    Label("settings.concurrent_downloads.label".localized(),systemImage: "").labelStyle(.titleOnly)
                }
            }
            .padding(.bottom, 20) // 只控制Section之间的垂直间距
            Section {
                TextField("settings.minecraft_versions_url.label".localized(), text: $gameSettings.minecraftVersionManifestURL).focusable(false)
                TextField("settings.modrinth_api_url.label".localized(), text: $gameSettings.modrinthAPIBaseURL).focusable(false)
                TextField("settings.git_proxy_url.label".localized(), text: $gameSettings.gitProxyURL).focusable(false)
            }
            
        }
        .alert("common.error".localized(), isPresented: $showingErrorAlert) {
            Button("common.ok".localized()) { }
        } message: {
            Text(errorMessage)
        }
        .globalErrorHandler()
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
            
            general.launcherWorkingDirectory = supportDir.path
            gameRepository.loadGames()
            
            Logger.shared.info("工作目录已重置为: \(supportDir.path)")
        } catch {
            let globalError = GlobalError.from(error)
            GlobalErrorHandler.shared.handle(globalError)
            showError(globalError.chineseMessage)
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
                    
                    general.launcherWorkingDirectory = url.path
                    gameRepository.loadGames()
                    
                    Logger.shared.info("工作目录已设置为: \(url.path)")
                } catch {
                    let globalError = GlobalError.from(error)
                    GlobalErrorHandler.shared.handle(globalError)
                    showError(globalError.chineseMessage)
                }
            }
        case .failure(let error):
            let globalError = GlobalError.fileSystem(
                chineseMessage: "选择目录失败: \(error.localizedDescription)",
                i18nKey: "error.filesystem.directory_selection_failed",
                level: .notification
            )
            GlobalErrorHandler.shared.handle(globalError)
            showError(globalError.chineseMessage)
        }
    }
    
    /// 安全地重启应用
    private func restartAppSafely() {
        do {
            try restartApp()
        } catch {
            let globalError = GlobalError.from(error)
            GlobalErrorHandler.shared.handle(globalError)
            showError(globalError.chineseMessage)
        }
    }
    
    /// 显示错误信息
    private func showError(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
    }
}

/// 重启应用
/// - Throws: GlobalError 当重启失败时
private func restartApp() throws {
    // 使用更简单和可靠的重启方法
    let task = Process()
    task.launchPath = "/usr/bin/open"
    task.arguments = ["-a", Bundle.main.bundleIdentifier!]
    
    do {
        try task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    } catch {
        // 如果上面的方法失败，尝试备用方法
        guard let resourcePath = Bundle.main.resourcePath,
              let executableURL = Bundle.main.executableURL else {
            throw GlobalError.resource(
                chineseMessage: "无法获取应用资源路径",
                i18nKey: "error.resource.app_executable_not_found",
                level: .popup
            )
        }
        
        let url = URL(fileURLWithPath: resourcePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("MacOS")
            .appendingPathComponent(executableURL.lastPathComponent)
        
        let process = Process()
        process.executableURL = url
        process.arguments = CommandLine.arguments
        
        do {
            try process.run()
            NSApplication.shared.terminate(nil)
        } catch {
            // 如果所有方法都失败，抛出错误
            throw GlobalError.configuration(
                chineseMessage: "所有重启方法都失败了: \(error.localizedDescription)",
                i18nKey: "error.configuration.app_restart_failed",
                level: .popup
            )
        }
    }
}

#Preview {
    GeneralSettingsView()
}
