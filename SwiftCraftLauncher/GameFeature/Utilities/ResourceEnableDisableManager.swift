//
//  ResourceEnableDisableManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages the enabled and disabled state of local resources by toggling a `.disable` file extension.
enum ResourceEnableDisableManager {
    /// Returns a Boolean value indicating whether the resource is disabled.
    /// - Parameter fileName: The file name to check, or `nil`.
    /// - Returns: `true` if the file name ends with `.disable`; otherwise `false`.
    static func isDisabled(fileName: String?) -> Bool {
        guard let fileName else { return false }
        return fileName.hasSuffix(".disable")
    }

    /// Toggles the enabled or disabled state of a resource by renaming the file.
    /// - Parameters:
    ///   - fileName: The current file name.
    ///   - resourceDir: The directory containing the resource.
    /// - Returns: The new file name after toggling.
    /// - Throws: A file-system error if the rename operation fails.
    static func toggleDisableState(
        fileName: String,
        resourceDir: URL,
    ) throws -> String {
        let fileManager = FileManager.default
        let currentURL = resourceDir.appendingPathComponent(fileName)
        let targetFileName: String

        let isCurrentlyDisabled = fileName.hasSuffix(".disable")
        if isCurrentlyDisabled {
            targetFileName = String(fileName.dropLast(".disable".count))
        } else {
            targetFileName = fileName + ".disable"
        }

        let targetURL = resourceDir.appendingPathComponent(targetFileName)
        try fileManager.moveItem(at: currentURL, to: targetURL)

        return targetFileName
    }
}
