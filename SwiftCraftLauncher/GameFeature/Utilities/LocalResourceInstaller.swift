import Foundation

/// 工具类：负责将本地 jar/zip 文件导入到指定资源目录
enum LocalResourceInstaller {
    enum LocalResourceType {
        case mod, datapack, resourcepack

        var directoryName: String {
            switch self {
            case .mod: return AppConstants.DirectoryNames.mods
            case .datapack: return AppConstants.DirectoryNames.datapacks
            case .resourcepack: return AppConstants.DirectoryNames.resourcepacks
            }
        }

        /// 支持的文件扩展名 - 统一支持 jar 和 zip
        var allowedExtensions: [String] {
            return ["jar", "zip"]
        }
    }

    /// 安装本地资源文件到指定目录
    /// - Parameters:
    ///   - fileURL: 用户选中的本地文件
    ///   - resourceType: 资源类型（mods/datapacks/resourcepacks）
    ///   - gameRoot: 游戏根目录（如 .minecraft）
    /// - Throws: GlobalError
    static func install(fileURL: URL, resourceType: LocalResourceType, gameRoot: URL) throws {
        // 检查扩展名
        guard let ext = fileURL.pathExtension.lowercased() as String?,
              resourceType.allowedExtensions.contains(ext) else {
            throw GlobalError.resource(
                chineseMessage: "不支持的文件类型。请导入 .jar 或 .zip 文件。",
                i18nKey: "error.resource.invalid_file_type",
                level: .notification
            )
        }

        // 目标目录
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: gameRoot.path, isDirectory: &isDir), isDir.boolValue else {
            throw GlobalError.fileSystem(
                chineseMessage: "目标文件夹不存在。",
                i18nKey: "error.filesystem.destination_unavailable",
                level: .notification
            )
        }

        // 处理安全作用域
        let needsSecurity = fileURL.startAccessingSecurityScopedResource()
        defer { if needsSecurity { fileURL.stopAccessingSecurityScopedResource() } }
        if !needsSecurity {
            throw GlobalError.fileSystem(
                chineseMessage: "无法访问所选文件。",
                i18nKey: "error.filesystem.security_scope_failed",
                level: .notification
            )
        }

        // 目标文件路径
        let destURL = gameRoot.appendingPathComponent(fileURL.lastPathComponent)

        // 如果已存在，先移除
        if FileManager.default.fileExists(atPath: destURL.path) {
            try? FileManager.default.removeItem(at: destURL)
        }

        do {
            try FileManager.default.copyItem(at: fileURL, to: destURL)
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "文件复制失败：\(error.localizedDescription)",
                i18nKey: "error.filesystem.copy_failed",
                level: .notification
            )
        }
    }
}
