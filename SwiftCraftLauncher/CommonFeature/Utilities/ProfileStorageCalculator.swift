//
//  ProfileStorageCalculator.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Represents the storage usage of a game profile.
struct ProfileStorageInfo: Equatable {
    /// The number of `.zip`/`.jar` archives in the profile.
    let archiveCount: Int
    /// The total size of every file in the profile, in bytes.
    let totalSize: Int64
    let formattedSize: String

    init(archiveCount: Int, totalSize: Int64) {
        self.archiveCount = archiveCount
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

/// Measures the storage usage of game profile directories.
class ProfileStorageCalculator {
    init() { }

    /// Returns the number of `.zip`/`.jar` files and the total size of a directory.
    ///
    /// Only archive files contribute to `archiveCount`; every file contributes to `size`.
    /// - Parameter directory: The directory to measure.
    /// - Returns: A tuple containing the archive count and total size in bytes.
    /// - Throws: A ``GlobalError`` if the operation fails.
    private func measureDirectory(_ directory: URL) throws -> (archiveCount: Int, size: Int64) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else {
            return (0, 0)
        }

        var archiveCount = 0
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
                    let ext = fileURL.pathExtension.lowercased()
                    if ext == "zip" || ext == "jar" {
                        archiveCount += 1
                    }
                    totalSize += Int64(fileSize)
                }
            } catch {
                AppLog.common.error("Unable to get file size: \(fileURL.path), error: \(error.localizedDescription)")
            }
        }

        return (archiveCount, totalSize)
    }

    /// Calculates the storage usage of a specific game profile.
    /// - Parameter gameName: The name of the game.
    /// - Returns: Storage information for the profile.
    /// - Throws: A ``GlobalError`` if the operation fails.
    func calculateProfileStorage(gameName: String) throws -> ProfileStorageInfo {
        let subdirectories = AppPaths.profileSubdirectories
        var totalArchiveCount = 0
        var totalSize: Int64 = 0

        for subdir in subdirectories {
            let subdirPath = AppPaths.profileDirectory(gameName: gameName).appendingPathComponent(subdir)
            let (archiveCount, size) = try measureDirectory(subdirPath)
            totalArchiveCount += archiveCount
            totalSize += size
        }

        return ProfileStorageInfo(archiveCount: totalArchiveCount, totalSize: totalSize)
    }
}
