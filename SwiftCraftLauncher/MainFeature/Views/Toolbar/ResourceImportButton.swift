//
//  ResourceImportButton.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Toolbar button that presents a file importer for local resource installation.
//
// Supports importing `.jar` and `.zip` files for mods, datapacks, and resource packs.

import SwiftUI
import UniformTypeIdentifiers

struct ResourceImportButton: View {
    let game: GameVersionInfo
    let gameResourcesType: String

    @State private var showImporter = false
    @StateObject private var errorHandler: GlobalErrorHandler

    init(
        game: GameVersionInfo,
        gameResourcesType: String,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
    ) {
        self.game = game
        self.gameResourcesType = gameResourcesType
        _errorHandler = StateObject(wrappedValue: errorHandler)
    }

    var body: some View {
        Button {
            showImporter = true
        } label: {
            Label("common.import".localized(), systemImage: "document.badge.plus")
        }
        .help("common.import".localized())
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: {
                var types: [UTType] = []
                if let jarType = UTType(filenameExtension: "jar") {
                    types.append(jarType)
                }
                types.append(.zip)
                return types
            }(),
            allowsMultipleSelection: true,
        ) { result in
            switch result {
            case let .success(urls):
                guard !urls.isEmpty else { return }
                importSelectedFiles(urls)
            case let .failure(error):
                errorHandler.handle(GlobalError.fileSystem(
                    chineseMessage: "文件选择失败：\(error.localizedDescription)",
                    i18nKey: "error.filesystem.file_selection_failed",
                    level: .notification,
                ))
            }
        }
    }

    /// Imports the selected files into the appropriate game resource directory.
    private func importSelectedFiles(_ urls: [URL]) {
        let queryLowercased = gameResourcesType.lowercased()

        if queryLowercased == ResourceType.modpack.rawValue
            || !AppConstants.validResourceTypes.contains(queryLowercased) {
            errorHandler.handle(GlobalError.configuration(
                chineseMessage: "不支持导入此类型的资源",
                i18nKey: "error.configuration.resource_directory_not_found",
                level: .notification,
            ))
            return
        }

        guard let gameRoot = AppPaths.resourceDirectory(for: gameResourcesType, gameName: game.gameName) else {
            errorHandler.handle(GlobalError.fileSystem(
                chineseMessage: "找不到游戏目录",
                i18nKey: "error.filesystem.game_directory_not_found",
                level: .notification,
            ))
            return
        }

        let allowedExtensions = ["jar", "zip"]
        var importedCount = 0

        for fileURL in urls {
            do {
                guard let ext = fileURL.pathExtension.lowercased() as String?,
                      allowedExtensions.contains(ext)
                else {
                    throw GlobalError.resource(
                        chineseMessage: "不支持的文件类型。请导入 .jar 或 .zip 文件。",
                        i18nKey: "error.resource.invalid_file_type",
                        level: .notification,
                    )
                }

                try LocalResourceInstaller.install(
                    fileURL: fileURL,
                    resourceType: {
                        switch queryLowercased {
                        case "mod": return .mod
                        case "datapack": return .datapack
                        case "resourcepack": return .resourcepack
                        default: return .mod
                        }
                    }(),
                    gameRoot: gameRoot,
                )
                importedCount += 1
            } catch {
                errorHandler.handle(error)
            }
        }

        if importedCount > 0 {
            NotificationCenter.default.post(name: .localResourceImported, object: nil)
        }
    }
}
