//
//  SwitchModLoaderSheetViewModel+Save.swift
//  SwiftCraftLauncher
//
//  Created by Hongbro886 on 2026/4/3.
//

import SwiftUI

extension SwitchModLoaderSheetViewModel {
    // MARK: - Installation

    func installModLoader() async -> Bool {
        isInstalling = true
        installError = nil
        installProgress = ("switch.modloader.preparing".localized(), 0, 0)

        defer {
            isInstalling = false
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
                gameInfo: gameInfo
            ) { [weak self] message, completed, total in
                Task { @MainActor in
                    self?.installProgress = (message, completed, total)
                }
            }

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
            _ = gameRepository?.updateGameSilently(updatedGame)

            return true
        } catch {
            let globalError = GlobalError.from(error)
            installError = globalError.chineseMessage
            GlobalErrorHandler.shared.handle(error)
            return false
        }
    }
}
