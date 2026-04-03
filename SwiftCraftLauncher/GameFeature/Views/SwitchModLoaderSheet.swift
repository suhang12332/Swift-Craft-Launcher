//
//  SwitchModLoaderSheet.swift
//  SwiftCraftLauncher
//
//  Created by Hongbro886 on 2026/4/2.
//

import SwiftUI

struct SwitchModLoaderSheet: View {
    let gameInfo: GameVersionInfo
    @Environment(\.dismiss)
    var dismiss
    @EnvironmentObject var gameRepository: GameRepository

    @State private var selectedModLoader: String = ""
    @State private var selectedLoaderVersion: String = ""
    @State private var availableLoaderVersions: [String] = []
    @State private var isLoadingVersions = false
    @State private var isInstalling = false
    @State private var installProgress: (message: String, completed: Int, total: Int) = ("", 0, 0)
    @State private var installError: String?
    @State private var versionLoadError: String?

    private var availableModLoaders: [String] {
        AppConstants.modLoaders.filter { $0 != GameLoader.vanilla.displayName }
    }

    private var headerView: some View {
        Text("switch.modloader.title".localized())
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var bodyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 当前游戏信息
            VStack(alignment: .leading, spacing: 8) {
                Text("switch.modloader.current_game".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Text(gameInfo.gameName)
                        .font(.body)
                        .fontWeight(.medium)
                    Text("-")
                        .foregroundColor(.secondary)
                    Text(gameInfo.gameVersion)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // ModLoader选择
            modLoaderPicker

            // 加载器版本选择
            if selectedModLoader != GameLoader.vanilla.displayName {
                loaderVersionPicker
            }

            // 版本加载错误提示
            if let versionError = versionLoadError {
                Text(versionError)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
            }

            // 安装进度
            if isInstalling {
                installProgressView
            }

            // 安装错误信息
            if let error = installError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .onAppear {
            initializeDefaultLoader()
        }
        .onChange(of: selectedModLoader) { _, newLoader in
            handleModLoaderChange(newLoader)
        }
    }

    private var modLoaderPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("game.form.modloader".localized())
                .font(.subheadline)
                .foregroundColor(.primary)
            CommonMenuPicker(
                selection: $selectedModLoader,
                hidesLabel: true
            ) {
                Text("")
            } content: {
                ForEach(availableModLoaders, id: \.self) { loader in
                    switch loader {
                    case GameLoader.fabric.displayName:
                        Text("modloader.fabric.text".localized()).tag(loader)
                    case GameLoader.forge.displayName:
                        Text("modloader.forge.text".localized()).tag(loader)
                    case GameLoader.neoforge.displayName:
                        Text("modloader.neoforge.text".localized()).tag(loader)
                    case GameLoader.quilt.rawValue:
                        Text("modloader.quilt.text".localized()).tag(loader)
                    default:
                        Text(loader.capitalized).tag(loader)
                    }
                }
            }
            .disabled(isInstalling || isLoadingVersions)
        }
    }

    private var loaderVersionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("game.form.loader.version".localized())
                .font(.subheadline)
                .foregroundColor(.primary)

            CommonMenuPicker(
                selection: $selectedLoaderVersion,
                hidesLabel: true
            ) {
                Text("")
            } content: {
                ForEach(availableLoaderVersions, id: \.self) { version in
                    Text(version).tag(version)
                }
            }
            .disabled(isInstalling || isLoadingVersions || availableLoaderVersions.isEmpty)
        }
    }

    private var installProgressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: Double(installProgress.completed), total: Double(max(installProgress.total, 1))) {
                Text(installProgress.message)
                    .font(.caption)
                    .lineLimit(1)
            }
            .progressViewStyle(.linear)

            Text("\(installProgress.completed) / \(installProgress.total)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }

    private var footerView: some View {
        HStack {
            Button("common.cancel".localized()) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .disabled(isInstalling)

            Spacer()

            Button {
                Task {
                    await installModLoader()
                }
            } label: {
                if isInstalling {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                } else {
                    Text("resource.add".localized())
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canInstall)
        }
    }

    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView }
        )
        .frame(width: 400)
    }

    // MARK: - Computed Properties

    private var canInstall: Bool {
        !selectedModLoader.isEmpty &&
        !selectedLoaderVersion.isEmpty &&
        !isInstalling &&
        !isLoadingVersions
    }

    // MARK: - Initialization

    private func initializeDefaultLoader() {
        // 默认选择第一个ModLoader并加载版本
        if let firstLoader = availableModLoaders.first {
            selectedModLoader = firstLoader
            // onChange会自动触发版本加载
        }
    }

    // MARK: - Data Loading

    private func handleModLoaderChange(_ newLoader: String) {
        guard !newLoader.isEmpty else { return }

        Task {
            await loadLoaderVersions(for: newLoader)
        }
    }

    private func loadLoaderVersions(for loader: String) async {
        await MainActor.run {
            isLoadingVersions = true
            availableLoaderVersions = []
            selectedLoaderVersion = ""
            versionLoadError = nil
        }

        defer {
            Task { @MainActor in
                isLoadingVersions = false
            }
        }

        let gameVersion = gameInfo.gameVersion
        var versions: [String] = []
        var loadError: Error?

        switch loader.lowercased() {
        case GameLoader.fabric.displayName:
            let fabricVersions = await FabricLoaderService.fetchAllLoaderVersions(for: gameVersion)
            versions = fabricVersions.map { $0.loader.version }
        case GameLoader.forge.displayName:
            do {
                let forgeVersions = try await ForgeLoaderService.fetchAllForgeVersions(for: gameVersion)
                versions = forgeVersions.loaders.map { $0.id }
            } catch {
                loadError = error
                Logger.shared.error("获取 Forge 版本失败: \(error.localizedDescription)")
            }
        case GameLoader.neoforge.displayName:
            do {
                let neoforgeVersions = try await NeoForgeLoaderService.fetchAllNeoForgeVersions(for: gameVersion)
                versions = neoforgeVersions.loaders.map { $0.id }
            } catch {
                loadError = error
                Logger.shared.error("获取 NeoForge 版本失败: \(error.localizedDescription)")
            }
        case GameLoader.quilt.rawValue:
            let quiltVersions = await QuiltLoaderService.fetchAllQuiltLoaders(for: gameVersion)
            versions = quiltVersions.map { $0.loader.version }
        default:
            break
        }

        await MainActor.run {
            availableLoaderVersions = versions
            if let firstVersion = versions.first {
                selectedLoaderVersion = firstVersion
            }

            // 如果版本列表为空，显示错误提示
            if versions.isEmpty {
                if let error = loadError {
                    let globalError = GlobalError.from(error)
                    versionLoadError = String(format: "switch.modloader.no_versions_for_loader".localized(), getModLoaderDisplayName(loader), gameVersion)
                } else {
                    versionLoadError = String(format: "switch.modloader.no_versions_for_loader".localized(), getModLoaderDisplayName(loader), gameVersion)
                }
            }
        }
    }

    private func getModLoaderDisplayName(_ loader: String) -> String {
        switch loader {
        case GameLoader.fabric.displayName:
            return "modloader.fabric.text".localized()
        case GameLoader.forge.displayName:
            return "modloader.forge.text".localized()
        case GameLoader.neoforge.displayName:
            return "modloader.neoforge.text".localized()
        case GameLoader.quilt.rawValue:
            return "modloader.quilt.text".localized()
        default:
            return loader.capitalized
        }
    }

    // MARK: - Installation

    private func installModLoader() async {
        await MainActor.run {
            isInstalling = true
            installError = nil
            installProgress = ("switch.modloader.preparing".localized(), 0, 0)
        }

        defer {
            Task { @MainActor in
                isInstalling = false
            }
        }

        do {
            // 获取对应的ModLoaderHandler
            let handler = getModLoaderHandler(for: selectedModLoader)
            guard let handler = handler else {
                throw GlobalError.validation(
                    chineseMessage: "不支持的模组加载器类型: \(selectedModLoader)",
                    i18nKey: "error.validation.unsupported_modloader",
                    level: .notification
                )
            }

            // 安装ModLoader
            let result = try await handler.setupWithSpecificVersionThrowing(
                for: gameInfo.gameVersion,
                loaderVersion: selectedLoaderVersion,
                gameInfo: gameInfo,
                onProgressUpdate: { message, completed, total in
                    Task { @MainActor in
                        self.installProgress = (message, completed, total)
                    }
                }
            )

            // 获取额外的加载器信息（JVM参数、游戏参数等）
            let (modJvm, gameArguments) = try await fetchLoaderArguments(
                loader: selectedModLoader,
                gameVersion: gameInfo.gameVersion,
                loaderVersion: selectedLoaderVersion
            )

            // 获取启动命令
            var launchCommand: [String] = []
            if let manifest = try? await ModrinthService.fetchVersionInfo(from: gameInfo.gameVersion) {
                let launcherBrand = Bundle.main.appName
                let launcherVersion = Bundle.main.fullVersion

                // 创建临时游戏信息用于构建启动命令
                let tempGameInfo = GameVersionInfo(
                    id: UUID(uuidString: gameInfo.id) ?? UUID(),
                    gameName: gameInfo.gameName,
                    gameIcon: gameInfo.gameIcon,
                    gameVersion: gameInfo.gameVersion,
                    modVersion: result.loaderVersion,
                    modJvm: modJvm,
                    modClassPath: result.classpath,
                    assetIndex: gameInfo.assetIndex,
                    modLoader: selectedModLoader,
                    lastPlayed: gameInfo.lastPlayed,
                    javaPath: gameInfo.javaPath,
                    jvmArguments: gameInfo.jvmArguments,
                    launchCommand: gameInfo.launchCommand,
                    xms: gameInfo.xms,
                    xmx: gameInfo.xmx,
                    javaVersion: gameInfo.javaVersion,
                    mainClass: result.mainClass,
                    gameArguments: gameArguments,
                    environmentVariables: gameInfo.environmentVariables
                )

                launchCommand = MinecraftLaunchCommandBuilder.build(
                    manifest: manifest,
                    gameInfo: tempGameInfo,
                    launcherBrand: launcherBrand,
                    launcherVersion: launcherVersion
                )
            }

            // 创建更新后的游戏信息（因为 modLoader 是 let，需要重新创建实例）
            let updatedGame = GameVersionInfo(
                id: UUID(uuidString: gameInfo.id) ?? UUID(),
                gameName: gameInfo.gameName,
                gameIcon: gameInfo.gameIcon,
                gameVersion: gameInfo.gameVersion,
                modVersion: result.loaderVersion,
                modJvm: modJvm,
                modClassPath: result.classpath,
                assetIndex: gameInfo.assetIndex,
                modLoader: selectedModLoader,
                lastPlayed: gameInfo.lastPlayed,
                javaPath: gameInfo.javaPath,
                jvmArguments: gameInfo.jvmArguments,
                launchCommand: launchCommand,
                xms: gameInfo.xms,
                xmx: gameInfo.xmx,
                javaVersion: gameInfo.javaVersion,
                mainClass: result.mainClass,
                gameArguments: gameArguments,
                environmentVariables: gameInfo.environmentVariables
            )

            // 保存到数据库
            _ = gameRepository.updateGameSilently(updatedGame)

            // 关闭Sheet
            await MainActor.run {
                dismiss()
            }
        } catch {
            let globalError = GlobalError.from(error)
            await MainActor.run {
                installError = globalError.chineseMessage
            }
            GlobalErrorHandler.shared.handle(error)
        }
    }

    private func getModLoaderHandler(for loader: String) -> (any ModLoaderHandler.Type)? {
        switch loader.lowercased() {
        case GameLoader.fabric.displayName:
            return FabricLoaderService.self
        case GameLoader.forge.displayName:
            return ForgeLoaderService.self
        case GameLoader.neoforge.displayName:
            return NeoForgeLoaderService.self
        case GameLoader.quilt.rawValue:
            return QuiltLoaderService.self
        default:
            return nil
        }
    }

    private func fetchLoaderArguments(loader: String, gameVersion: String, loaderVersion: String) async throws -> (modJvm: [String], gameArguments: [String]) {
        var modJvm: [String] = []
        var gameArguments: [String] = []

        switch loader.lowercased() {
        case GameLoader.fabric.displayName:
            if let fabricLoader = try? await FabricLoaderService.fetchSpecificLoaderVersion(for: gameVersion, loaderVersion: loaderVersion) {
                modJvm = fabricLoader.arguments.jvm ?? []
                gameArguments = fabricLoader.arguments.game ?? []
            }
        case GameLoader.quilt.rawValue:
            if let quiltLoader = try? await QuiltLoaderService.fetchSpecificLoaderVersion(for: gameVersion, loaderVersion: loaderVersion) {
                modJvm = quiltLoader.arguments.jvm ?? []
                gameArguments = quiltLoader.arguments.game ?? []
            }
        case GameLoader.forge.displayName:
            if let forgeLoader = try? await ForgeLoaderService.fetchSpecificForgeProfile(for: gameVersion, loaderVersion: loaderVersion) {
                gameArguments = forgeLoader.arguments.game ?? []
                let jvmArgs = forgeLoader.arguments.jvm ?? []
                modJvm = jvmArgs.map { arg in
                    arg.replacingOccurrences(of: "${version_name}", with: gameVersion)
                        .replacingOccurrences(of: "${classpath_separator}", with: ":")
                        .replacingOccurrences(of: "${library_directory}", with: AppPaths.librariesDirectory.path)
                }
            }
        case GameLoader.neoforge.displayName:
            if let neoForgeLoader = try? await NeoForgeLoaderService.fetchSpecificNeoForgeProfile(for: gameVersion, loaderVersion: loaderVersion) {
                gameArguments = neoForgeLoader.arguments.game ?? []
                let jvmArgs = neoForgeLoader.arguments.jvm ?? []
                modJvm = jvmArgs.map { arg -> String in
                    let mutableArg = NSMutableString(string: arg)
                    mutableArg.replaceOccurrences(
                        of: "${version_name}",
                        with: gameVersion,
                        options: [],
                        range: NSRange(location: 0, length: mutableArg.length)
                    )
                    mutableArg.replaceOccurrences(
                        of: "${classpath_separator}",
                        with: ":",
                        options: [],
                        range: NSRange(location: 0, length: mutableArg.length)
                    )
                    mutableArg.replaceOccurrences(
                        of: "${library_directory}",
                        with: AppPaths.librariesDirectory.path,
                        options: [],
                        range: NSRange(location: 0, length: mutableArg.length)
                    )
                    return mutableArg as String
                }
            }
        default:
            break
        }

        return (modJvm, gameArguments)
    }
}

// MARK: - Preview
#Preview {
    SwitchModLoaderSheet(gameInfo: GameVersionInfo(
        gameName: "Test Game",
        gameIcon: "",
        gameVersion: "1.20.1",
        assetIndex: "",
        modLoader: "vanilla"
    ))
    .environmentObject(GameRepository())
}
