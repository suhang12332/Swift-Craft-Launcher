import Foundation

/// 解析包含 `modrinth.index.json` 的整合包（可以是 `.mrpack` 或 `.zip`）
struct ModrinthIndexAdapter: ModPackIndexAdapter {
    let id: String = "modrinth"

    private enum ModrinthIndexError: Error {
        case emptyIndex
    }

    func canParse(extractedPath: URL) async -> Bool {
        let indexPath = extractedPath.appendingPathComponent(AppConstants.modrinthIndexFileName)
        return await Task.detached(priority: .userInitiated) {
            let path = indexPath.path
            guard FileManager.default.fileExists(atPath: path) else { return false }
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: path)
                let size = attrs[.size] as? Int64 ?? 0
                return size > 0
            } catch {
                return false
            }
        }.value
    }

    func parseToModrinthIndexInfo(extractedPath: URL) async -> ModrinthIndexInfo? {
        let indexPath = extractedPath.appendingPathComponent(AppConstants.modrinthIndexFileName)
        do {
            let modPackIndex: ModrinthIndex = try await Task.detached(priority: .userInitiated) {
                let indexPathString = indexPath.path
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: indexPathString)
                let fileSize = fileAttributes[.size] as? Int64 ?? 0
                guard fileSize > 0 else { throw ModrinthIndexError.emptyIndex }
                let indexData = try Data(contentsOf: indexPath)
                return try JSONDecoder().decode(ModrinthIndex.self, from: indexData)
            }.value

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

    private func determineLoaderInfo(
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
