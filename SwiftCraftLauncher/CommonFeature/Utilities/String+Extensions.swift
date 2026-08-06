//
//  String+Extensions.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension String {
    /// Replaces JVM argument placeholders with actual values.
    func replacingJVMPlaceholders(
        gameVersion: String,
        libraryDirectory: String = AppPaths.librariesDirectory.path,
        classpathSeparator: String = ":",
    ) -> String {
        replacingOccurrences(of: AppConstants.JVMArgumentPlaceholders.versionName, with: gameVersion)
            .replacingOccurrences(of: AppConstants.JVMArgumentPlaceholders.classpathSeparator, with: classpathSeparator)
            .replacingOccurrences(of: AppConstants.JVMArgumentPlaceholders.libraryDirectory, with: libraryDirectory)
    }
}
