//
//  LauncherImportView.swift
//  SwiftCraftLauncher
//

import LauncherImportKit
import SwiftUI
import UniformTypeIdentifiers

struct LauncherImportView: View {
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @StateObject private var bridge: LauncherImportAppBridge
    @State private var selectedLauncherType: ImportLauncherType = .multiMC
    @State private var showFolderPicker = false

    private let triggerConfirm: Binding<Bool>
    private let triggerCancel: Binding<Bool>

    init(configuration: GameFormConfiguration) {
        triggerConfirm = configuration.triggerConfirm
        triggerCancel = configuration.triggerCancel
        _bridge = StateObject(wrappedValue: LauncherImportAppBridge(formConfiguration: configuration))
    }

    var body: some View {
        VStack(spacing: 16) {
            launcherSelectionSection
            LauncherImportKit.LauncherImportView(
                configuration: bridge.configuration(
                    for: selectedLauncherType,
                    folderPickerPresented: $showFolderPicker
                )
            )
            .id(selectedLauncherType)
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            bridge.hostCallbacks.handleSelection?(result)
        }
        .fileDialogDefaultDirectory(FileManager.default.homeDirectoryForCurrentUser)
        .onChange(of: triggerConfirm.wrappedValue) { _, newValue in
            if newValue {
                bridge.hostCallbacks.handleConfirm?()
                triggerConfirm.wrappedValue = false
            }
        }
        .onChange(of: triggerCancel.wrappedValue) { _, newValue in
            if newValue {
                bridge.hostCallbacks.handleCancel?()
                triggerCancel.wrappedValue = false
            }
        }
        .onAppear {
            bridge.gameRepository = gameRepository
            bridge.playerListViewModel = playerListViewModel
        }
        .onDisappear {
            bridge.cleanup()
        }
    }

    private var launcherSelectionSection: some View {
        FormSection {
            VStack(alignment: .leading, spacing: 8) {
                Text("launcher.import.select_launcher".localized())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                CommonMenuPicker(
                    selection: $selectedLauncherType,
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
}

@MainActor
private final class LauncherImportAppBridge: ObservableObject {
    private let formConfiguration: GameFormConfiguration
    let gameSetupService = GameSetupUtil()
    let gameNameValidator: GameNameValidator
    let hostCallbacks = LauncherImportHostCallbacks()

    var gameRepository: GameRepository?
    var playerListViewModel: PlayerListViewModel?

    init(formConfiguration: GameFormConfiguration) {
        self.formConfiguration = formConfiguration
        self.gameNameValidator = GameNameValidator(gameSetupService: gameSetupService)
    }

    func cleanup() {
        hostCallbacks.handleCleanup?()
        gameNameValidator.reset()
    }

    func configuration(
        for launcherType: ImportLauncherType,
        folderPickerPresented: Binding<Bool>
    ) -> LauncherImportConfiguration {
        LauncherImportConfiguration(
            launcherType: launcherType,
            folderPickerPresented: folderPickerPresented,
            hostCallbacks: hostCallbacks,
            isDownloading: formConfiguration.isDownloading,
            isFormValid: formConfiguration.isFormValid,
            triggerConfirm: formConfiguration.triggerConfirm,
            triggerCancel: formConfiguration.triggerCancel,
            gameName: Binding(
                get: { self.gameNameValidator.gameName },
                set: { self.gameNameValidator.gameName = $0 }
            ),
            isGameNameDuplicate: Binding(
                get: { self.gameNameValidator.isGameNameDuplicate },
                set: { self.gameNameValidator.isGameNameDuplicate = $0 }
            ),
            onComplete: formConfiguration.actions.onConfirm,
            onCancel: formConfiguration.actions.onCancel,
            profileDirectory: { AppPaths.profileDirectory(gameName: $0) },
            saveGame: { [self] request in
                guard let gameRepository, let playerListViewModel else { return false }
                return await withCheckedContinuation { continuation in
                    Task {
                        await gameSetupService.saveGame(
                            gameName: request.gameName,
                            selectedGameVersion: request.gameVersion,
                            selectedModLoader: request.modLoader,
                            specifiedLoaderVersion: request.modLoaderVersion,
                            pendingIconData: nil,
                            playerListViewModel: playerListViewModel,
                            gameRepository: gameRepository,
                            onSuccess: { continuation.resume(returning: true) },
                            onError: { error, message in
                                Logger.shared.error("游戏下载失败: \(message)")
                                AppServices.errorHandler.handle(error)
                                continuation.resume(returning: false)
                            }
                        )
                    }
                }
            },
            cleanupGame: { gameName in
                try? MinecraftFileManager().cleanupGameDirectories(gameName: gameName)
            },
            reportError: { Self.report($0) },
            isGameNameValid: { [self] in gameNameValidator.isFormValid },
            checkGameNameDuplicate: { [self] in await gameSetupService.checkGameNameDuplicate($0) },
            cancelDownload: { [self] in gameSetupService.downloadState.cancel() },
            resetDownloadState: { [self] in gameSetupService.downloadState.reset() },
            isGameDownloading: { [self] in gameSetupService.downloadState.isDownloading },
            downloadProgressView: AnyView(
                DownloadProgressSection(
                    gameSetupService: gameSetupService,
                    selectedModLoader: GameLoader.vanilla.displayName,
                    modPackViewModel: nil,
                    modPackIndexInfo: nil
                )
            )
        )
    }

    private static func report(_ error: LauncherImportUserError) {
        switch error {
        case .fileAccessFailed:
            AppServices.errorHandler.handle(
                GlobalError.fileSystem(
                    chineseMessage: "无法访问所选文件夹",
                    i18nKey: "error.filesystem.file_access_failed",
                    level: .notification
                )
            )
        case .invalidInstance:
            AppServices.errorHandler.handle(
                GlobalError.fileSystem(
                    chineseMessage: "选择的文件夹不是有效的启动器实例",
                    i18nKey: "error.filesystem.invalid_instance_path",
                    level: .notification
                )
            )
        case .parseFailed(let instanceName):
            AppServices.errorHandler.handle(
                GlobalError.fileSystem(
                    chineseMessage: "解析实例 \(instanceName) 失败：无法获取实例信息",
                    i18nKey: "error.filesystem.parse_instance_failed",
                    level: .notification
                )
            )
        case .missingGameVersion(let instanceName):
            AppServices.errorHandler.handle(
                GlobalError.fileSystem(
                    chineseMessage: "实例 \(instanceName) 没有游戏版本，无法导入",
                    i18nKey: "error.filesystem.instance_no_version",
                    level: .notification
                )
            )
        case .unsupportedModLoader(let instanceName, let modLoader, let supported):
            let supportedList = supported.joined(separator: "、")
            AppServices.errorHandler.handle(
                GlobalError.fileSystem(
                    chineseMessage: "实例 \(instanceName) 使用了不支持的 Mod Loader (\(modLoader))，仅支持 \(supportedList)",
                    i18nKey: "error.filesystem.unsupported_mod_loader",
                    level: .notification
                )
            )
        case .copyFailed(let message):
            AppServices.errorHandler.handle(
                GlobalError.fileSystem(
                    chineseMessage: "复制游戏目录失败: \(message)",
                    i18nKey: "error.filesystem.copy_game_directory_failed",
                    level: .notification
                )
            )
        }
    }
}
