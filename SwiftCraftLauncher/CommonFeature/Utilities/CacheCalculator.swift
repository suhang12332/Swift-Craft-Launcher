//
//  CacheCalculator.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Represents cache information including file count and total size.
struct CacheInfo: Equatable {
    let fileCount: Int
    let totalSize: Int64
    let formattedSize: String

    init(fileCount: Int, totalSize: Int64) {
        self.fileCount = fileCount
        self.totalSize = totalSize
        formattedSize = Self.formatFileSize(totalSize)
    }

    static func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

/// Calculates cache sizes for various application directories.
class CacheCalculator {
    static let shared = CacheCalculator()

    private init() { }

    /// Calculates cache information for game resource metadata.
    /// - Throws: A ``GlobalError`` if the operation fails.
    func calculateMetaCacheInfo() throws -> CacheInfo {
        let resourceTypes = AppConstants.cacheResourceTypes
        var totalFileCount = 0
        var totalSize: Int64 = 0

        for type in resourceTypes {
            let typeDir = AppPaths.metaDirectory.appendingPathComponent(type)
            let (fileCount, size) = try calculateDirectorySize(typeDir)
            totalFileCount += fileCount
            totalSize += size
        }

        return CacheInfo(fileCount: totalFileCount, totalSize: totalSize)
    }

    /// Calculates cache information for the application cache directory.
    /// - Throws: A ``GlobalError`` if the operation fails.
    func calculateCacheInfo() throws -> CacheInfo {
        let (fileCount, size) = try calculateDirectorySize(AppPaths.appCache)
        return CacheInfo(fileCount: fileCount, totalSize: size)
    }

    /// Returns the file count and total size of a directory.
    /// - Parameter directory: The directory to measure.
    /// - Returns: A tuple containing the file count and total size in bytes.
    /// - Throws: A ``GlobalError`` if the operation fails.
    private func calculateDirectorySize(_ directory: URL) throws -> (fileCount: Int, size: Int64) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else {
            return (0, 0)
        }

        var fileCount = 0
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.directory_enumeration_failed",
                level: .silent,
                message: "Failed to create enumerator for directory: \(directory.path)",
            )
        }

        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == ".DS_Store" {
                continue
            }

            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resourceValues.fileSize {
                    fileCount += 1
                    totalSize += Int64(fileSize)
                }
            } catch {
                AppLog.common.error("Unable to get file size: \(fileURL.path), error: \(error.localizedDescription)")
            }
        }

        return (fileCount, totalSize)
    }

    /// Calculates cache information for a specific game profile.
    /// - Parameter gameName: The name of the game.
    /// - Returns: Cache information for the profile.
    /// - Throws: A ``GlobalError`` if the operation fails.
    func calculateProfileCacheInfo(gameName: String) throws -> CacheInfo {
        let subdirectories = AppPaths.profileSubdirectories
        var totalFileCount = 0
        var totalSize: Int64 = 0

        for subdir in subdirectories {
            let subdirPath = AppPaths.profileDirectory(gameName: gameName).appendingPathComponent(subdir)
            let (fileCount, size) = try calculateDirectorySize(subdirPath)
            totalFileCount += fileCount
            totalSize += size
        }

        return CacheInfo(fileCount: totalFileCount, totalSize: totalSize)
    }
}
