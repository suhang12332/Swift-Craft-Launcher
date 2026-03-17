import Foundation

enum ModPackIndexParser {
    private enum ModrinthIndexError: Error {
        case emptyIndex
    }

    static func parseIndex(extractedPath: URL) async -> ModrinthIndexInfo? {
        if let modrinthInfo = await parseModrinthIndexInternal(extractedPath: extractedPath) {
            return modrinthInfo
        }

        if let modrinthInfo = await CurseForgeManifestParser.parseManifest(extractedPath: extractedPath) {
            return modrinthInfo
        }

        return nil
    }

    private static func parseModrinthIndexInternal(extractedPath: URL) async -> ModrinthIndexInfo? {
        let indexPath = extractedPath.appendingPathComponent(AppConstants.modrinthIndexFileName)
        do {
            let modPackIndex: ModrinthIndex? = try await Task.detached(priority: .userInitiated) { () throws -> ModrinthIndex? in
                let indexPathString = indexPath.path
                guard FileManager.default.fileExists(atPath: indexPathString) else { return nil }
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: indexPathString)
                let fileSize = fileAttributes[.size] as? Int64 ?? 0
                guard fileSize > 0 else { throw ModrinthIndexError.emptyIndex }
                let indexData = try Data(contentsOf: indexPath)
                return try JSONDecoder().decode(ModrinthIndex.self, from: indexData)
            }.value

            guard let modPackIndex else { return nil }
            let loaderInfo = determineLoaderInfo(from: modPackIndex.dependencies)
            return ModrinthIndexInfo(
                gameVersion: modPackIndex.dependencies.minecraft ?? "unknown",
                loaderType: loaderInfo.type,
                loaderVersion: loaderInfo.version,
                modPackName: modPackIndex.name,
                modPackVersion: modPackIndex.versionId,
                summary: modPackIndex.summary,
                files: modPackIndex.files,
                dependencies: modPackIndex.dependencies.dependencies ?? [],
                source: .modrinth
            )
        } catch ModrinthIndexError.emptyIndex {
            GlobalErrorHandler.shared.handle(
                GlobalError.resource(
                    chineseMessage: "modrinth.index.json 文件为空",
                    i18nKey: "error.resource.modrinth_index_empty",
                    level: .notification
                )
            )
            return nil
        } catch {
            if error is DecodingError {
                Logger.shared.error("解析 modrinth.index.json 失败: JSON 格式错误")
            }
            return nil
        }
    }

    private static func determineLoaderInfo(
        from dependencies: ModrinthIndexDependencies
    ) -> (type: String, version: String) {
        if let forgeVersion = dependencies.forgeLoader {
            return (GameLoader.forge.displayName, forgeVersion)
        } else if let fabricVersion = dependencies.fabricLoader {
            return (GameLoader.fabric.displayName, fabricVersion)
        } else if let quiltVersion = dependencies.quiltLoader {
            return (GameLoader.quilt.rawValue, quiltVersion)
        } else if let neoforgeVersion = dependencies.neoforgeLoader {
            return (GameLoader.neoforge.displayName, neoforgeVersion)
        }

        if let forgeVersion = dependencies.forge {
            return (GameLoader.forge.displayName, forgeVersion)
        } else if let fabricVersion = dependencies.fabric {
            return (GameLoader.fabric.displayName, fabricVersion)
        } else if let quiltVersion = dependencies.quilt {
            return (GameLoader.quilt.rawValue, quiltVersion)
        } else if let neoforgeVersion = dependencies.neoforge {
            return (GameLoader.neoforge.displayName, neoforgeVersion)
        }

        return (GameLoader.vanilla.displayName, "unknown")
    }
}
