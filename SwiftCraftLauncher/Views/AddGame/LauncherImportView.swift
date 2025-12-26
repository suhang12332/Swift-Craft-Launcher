//
//  LauncherImportView.swift
//  SwiftCraftLauncher
//
//

import SwiftUI

// MARK: - LauncherImportView
struct LauncherImportView: View {
    @StateObject private var viewModel: LauncherImportViewModel
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var playerListViewModel: PlayerListViewModel

    // Bindings from parent
    private let triggerConfirm: Binding<Bool>
    private let triggerCancel: Binding<Bool>
    @Environment(\.dismiss)
    private var dismiss

    // MARK: - Initializer
    init(configuration: GameFormConfiguration) {
        self.triggerConfirm = configuration.triggerConfirm
        self.triggerCancel = configuration.triggerCancel

        self._viewModel = StateObject(wrappedValue: LauncherImportViewModel(
            configuration: configuration
        ))
    }

    // MARK: - Body
    var body: some View {
        formContentView
            .onAppear {
                viewModel.setup(gameRepository: gameRepository, playerListViewModel: playerListViewModel)
            }
            .onDisappear {
                // Sheet 关闭时清理缓存
                viewModel.cleanup()
            }
            .gameFormStateListeners(viewModel: viewModel, triggerConfirm: triggerConfirm, triggerCancel: triggerCancel)
            .onChange(of: viewModel.selectedLauncherType) { _, _ in
                // 启动器类型改变时，清除之前的选择
                viewModel.selectedInstancePath = nil
            }
            .onChange(of: viewModel.selectedInstancePath) { _, newValue in
                // 当选中实例路径变化时，自动填充游戏名到输入框
                if newValue != nil {
                    viewModel.autoFillGameNameIfNeeded()
                    // 检查 Mod Loader 是否支持，如果不支持则显示通知
                    viewModel.checkAndNotifyUnsupportedModLoader()
                }
            }
    }

    // MARK: - View Components

    private var formContentView: some View {
        VStack(spacing: 16) {
            launcherSelectionSection
            pathSelectionSection
            if viewModel.currentInstanceInfo != nil {
                instanceInfoSection
            }
            gameNameInputSection
            if viewModel.shouldShowProgress {
                VStack(spacing: 16) {
                    // 显示复制进度（如果正在复制）
                    if viewModel.isImporting, let progress = viewModel.importProgress {
                        importProgressSection(progress: progress)
                    }
                    // 显示下载进度
                    downloadProgressSection
                }
                .padding(.top, 10)
            }
        }
    }

    private var launcherSelectionSection: some View {
        FormSection {
            VStack(alignment: .leading, spacing: 8) {
                Text("launcher.import.select_launcher".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $viewModel.selectedLauncherType) {
                    ForEach(ImportLauncherType.allCases, id: \.self) { launcherType in
                        Text(launcherType.rawValue)
                            .tag(launcherType)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }

    private var pathSelectionSection: some View {
        FormSection {
            VStack(alignment: .leading, spacing: 8) {
                Text("launcher.import.select_instance_folder".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    if let path = viewModel.selectedInstancePath?.path {
                        PathBreadcrumbView(path: path)
                    } else {
                        Text("launcher.import.no_path_selected".localized())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("common.browse".localized()) {
                        selectLauncherPath()
                    }
                }
            }
        }
    }

    @ViewBuilder private var instanceInfoSection: some View {
        if let info = viewModel.currentInstanceInfo {
            FormSection {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        // 游戏名称
                        HStack {
                            Text("game.form.name".localized())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(info.gameName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // 游戏版本
                        HStack {
                            Text("game.form.version".localized())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Label(info.gameVersion, systemImage: "gamecontroller.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Mod 加载器
                        if !info.modLoader.isEmpty && info.modLoader != "vanilla" {
                            HStack {
                                Text("game.form.modloader".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                HStack(spacing: 4) {
                                    Label(info.modLoader.capitalized, systemImage: "puzzlepiece.extension.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    if !info.modLoaderVersion.isEmpty {
                                        Text("(\(info.modLoaderVersion))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var gameNameInputSection: some View {
        FormSection {
            GameNameInputView(
                gameName: Binding(
                    get: { viewModel.gameNameValidator.gameName },
                    set: { viewModel.gameNameValidator.gameName = $0 }
                ),
                isGameNameDuplicate: Binding(
                    get: { viewModel.gameNameValidator.isGameNameDuplicate },
                    set: { viewModel.gameNameValidator.isGameNameDuplicate = $0 }
                ),
                isDisabled: viewModel.isImporting || viewModel.isDownloading,
                gameSetupService: viewModel.gameSetupService
            )
        }
    }

    private var downloadProgressSection: some View {
        // 获取选中实例的 modLoader，如果没有则使用 "vanilla"
        let selectedModLoader: String = {
            if let info = viewModel.currentInstanceInfo {
                return info.modLoader
            }
            return "vanilla"
        }()

        return DownloadProgressSection(
            gameSetupService: viewModel.gameSetupService,
            selectedModLoader: selectedModLoader,
            modPackViewModel: nil,
            modPackIndexInfo: nil
        )
    }

    private func importProgressSection(progress: (fileName: String, completed: Int, total: Int)) -> some View {
        FormSection {
            DownloadProgressRow(
                title: "launcher.import.copying_files".localized(),
                progress: progress.total > 0 ? Double(progress.completed) / Double(progress.total) : 0.0,
                currentFile: progress.fileName,
                completed: progress.completed,
                total: progress.total,
                version: nil
            )
        }
    }

    // MARK: - Helper Methods

    private func selectLauncherPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canSelectHiddenExtension = true  // 允许访问隐藏目录（如 Library）

        // 设置初始目录为用户home目录
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        if panel.runModal() == .OK {
            if let url = panel.url {
                // 保持安全作用域资源访问权限
                _ = url.startAccessingSecurityScopedResource()

                // 验证选择的文件夹是否为有效实例
                guard viewModel.validateInstance(at: url) else {
                    let launcherName = viewModel.selectedLauncherType.rawValue
                    GlobalErrorHandler.shared.handle(
                        GlobalError.fileSystem(
                            chineseMessage: "选择的文件夹不是有效的 \(launcherName) 实例",
                            i18nKey: "error.filesystem.invalid_instance_path",
                            level: .notification
                        )
                    )
                    return
                }

                // 直接使用选择的实例路径
                viewModel.selectedInstancePath = url

                // 自动填充游戏名到输入框
                viewModel.autoFillGameNameIfNeeded()

                Logger.shared.info("成功选择 \(viewModel.selectedLauncherType.rawValue) 实例路径: \(url.path)")
            }
        }
    }

    #Preview {
        struct PreviewWrapper: View {
            @State private var isDownloading = false
            @State private var isFormValid = false
            @State private var triggerConfirm = false
            @State private var triggerCancel = false

            var body: some View {
                LauncherImportView(
                    configuration: GameFormConfiguration(
                        isDownloading: $isDownloading,
                        isFormValid: $isFormValid,
                        triggerConfirm: $triggerConfirm,
                        triggerCancel: $triggerCancel,
                        onCancel: {},
                        onConfirm: {}
                    )
                )
                .environmentObject(GameRepository())
                .environmentObject(PlayerListViewModel())
                .frame(width: 600, height: 500)
                .padding()
            }
        }
        return PreviewWrapper()
    }
}
