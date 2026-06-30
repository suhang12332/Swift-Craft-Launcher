//
//  ModPackDependencyInstaller+Overrides.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModPackDependencyInstaller {
    /// Installs override files from the extracted modpack into the game directory.
    static func installOverrides(
        extractedPath: URL,
        resourceDir: URL,
        onProgressUpdate: ((String, Int, Int, DownloadType) -> Void)?,
    ) async -> Bool {
        var overridesPath = extractedPath.appendingPathComponent("overrides")

        if !FileManager.default.fileExists(atPath: overridesPath.path) {
            let possiblePaths = ["overrides", "Override", "override"]

            var foundPath: URL?
            for pathName in possiblePaths {
                let testPath = extractedPath.appendingPathComponent(pathName)
                if FileManager.default.fileExists(atPath: testPath.path) {
                    foundPath = testPath
                    break
                }
            }

            if let found = foundPath {
                overridesPath = found
            } else {
                return true
            }
        }

        do {
            let allFiles = try InstanceFileCopier.getAllFiles(in: overridesPath)
            let totalFiles = allFiles.count

            guard totalFiles > 0 else {
                return true
            }

            try await InstanceFileCopier.copyDirectory(
                from: overridesPath,
                to: resourceDir,
                fileFilter: nil,
            ) { fileName, completed, total in
                onProgressUpdate?(fileName, completed, total, .overrides)
            }

            return true
        } catch {
            Logger.shared.error("处理 overrides 文件夹失败: \(error.localizedDescription)")
            return false
        }
    }
}
