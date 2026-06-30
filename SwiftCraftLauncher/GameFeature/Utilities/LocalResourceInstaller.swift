//
//  LocalResourceInstaller.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Installs local jar or zip files into the appropriate resource directory.
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

        /// The file extensions that are allowed for this resource type.
        var allowedExtensions: [String] {
            return ["jar", "zip"]
        }
    }

    /// Installs a local resource file into the specified directory.
    /// - Parameters:
    ///   - fileURL: The local file selected by the user.
    ///   - resourceType: The resource type (mods, datapacks, or resourcepacks).
    ///   - gameRoot: The game root directory (e.g., `.minecraft`).
    /// - Throws: A `GlobalError` if the file type is invalid, the destination is unavailable, or the copy fails.
    static func install(fileURL: URL, resourceType: LocalResourceType, gameRoot: URL) throws {
        guard let ext = fileURL.pathExtension.lowercased() as String?,
              resourceType.allowedExtensions.contains(ext) else {
            throw GlobalError.resource(
                chineseMessage: "不支持的文件类型。请导入 .jar 或 .zip 文件。",
                i18nKey: "error.resource.invalid_file_type",
                level: .notification
            )
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: gameRoot.path, isDirectory: &isDir), isDir.boolValue else {
            throw GlobalError.fileSystem(
                chineseMessage: "目标文件夹不存在。",
                i18nKey: "error.filesystem.destination_unavailable",
                level: .notification
            )
        }

        let needsSecurity = fileURL.startAccessingSecurityScopedResource()
        defer { if needsSecurity { fileURL.stopAccessingSecurityScopedResource() } }
        if !needsSecurity {
            throw GlobalError.fileSystem(
                chineseMessage: "无法访问所选文件。",
                i18nKey: "error.filesystem.security_scope_failed",
                level: .notification
            )
        }

        let destURL = gameRoot.appendingPathComponent(fileURL.lastPathComponent)

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
