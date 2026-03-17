//
//  LauncherImportView.swift
//  SwiftCraftLauncher
//
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - LauncherImportView
struct LauncherImportView: View {
    @StateObject private var viewModel: LauncherImportViewModel
    @StateObject private var folderPickerViewModel = LauncherImportFolderPickerViewModel()
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var playerListViewModel: PlayerListViewModel

    // Bindings from parent
    private let triggerConfirm: Binding<Bool>
    private let triggerCancel: Binding<Bool>
    @Environment(\.dismiss)
    private var dismiss

    // 文件选择器状态
    @State private var showFolderPicker = false

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
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleFolderSelection(result)
            }
            .fileDialogDefaultDirectory(FileManager.default.homeDirectoryForCurrentUser)
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

                CommonMenuPicker(
                    selection: $viewModel.selectedLauncherType,
                    hidesLabel: true
                ) {
                    Text("")
                } content: {
                    ForEach(ImportLauncherType.allCases, id: \.self) { launcherType in
                        Text(launcherType.rawValue)
                            .tag(launcherType)
                    }
                }
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
        showFolderPicker = true
    }

    /// 处理通过 fileImporter 选择的文件夹
    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        let launcherName = viewModel.selectedLauncherType.rawValue
        folderPickerViewModel.handleFolderSelection(
            result,
            launcherName: launcherName,
            validateInstance: { url in viewModel.validateInstance(at: url) },
            setSelectedInstancePath: { url in viewModel.selectedInstancePath = url },
            autoFillGameNameIfNeeded: { viewModel.autoFillGameNameIfNeeded() }
        )
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
