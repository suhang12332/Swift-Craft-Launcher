//
//  JavaManager.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages local Java runtime installation, validation, and discovery.
class JavaManager {
    private let fileManager = FileManager.default

    init() { }

    func getJavaExecutablePath(version: String) -> String {
        AppPaths.javaExecutablePath(version: version)
    }

    func findJavaExecutable(version: String) -> String {
        let javaPath = getJavaExecutablePath(version: version)

        guard fileManager.fileExists(atPath: javaPath) else {
            return ""
        }

        guard canJavaRun(at: javaPath) else {
            return ""
        }

        return javaPath
    }

    /// Lists installed runtime component names in the runtime directory, excluding legacy and pre-release versions.
    func listInstalledRuntimeComponents() -> [String] {
        let base = AppPaths.runtimeDirectory
        guard let names = try? fileManager.contentsOfDirectory(atPath: base.path) else {
            return []
        }
        return names.filter { name in
            guard !AppConstants.gameSettingsRuntimeExcludedComponents.contains(name) else { return false }
            var isDir: ObjCBool = false
            let path = base.appendingPathComponent(name).path
            guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
                return false
            }
            let javaPath = getJavaExecutablePath(version: name)
            return fileManager.isExecutableFile(atPath: javaPath)
        }
    }

    func canJavaRun(at javaPath: String) -> Bool {
        guard let result = runJavaCommand(at: javaPath, arguments: ["-version"]) else {
            AppLog.game.error("Java launch verification failed to start: \(javaPath)")
            return false
        }

        guard result.exitCode == 0 else {
            AppLog.game.error("Java launch verification failed, exit code: \(result.exitCode)")
            return false
        }

        AppLog.game.debug("Java launch verification succeeded: \(javaPath)")
        return true
    }

    /// Returns the output of `java --version` for the specified executable.
    /// - Parameter javaPath: The path to the Java executable.
    /// - Returns: The combined stdout and stderr output, or `nil` if execution fails.
    func getJavaVersionInfo(at javaPath: String) -> String? {
        guard let result = runJavaCommand(at: javaPath, arguments: ["--version"]),
              !result.output.isEmpty else {
            return nil
        }

        return String(data: result.output, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runJavaCommand(at javaPath: String, arguments: [String]) -> (exitCode: Int32, output: Data)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: javaPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, data)
        } catch {
            AppLog.game.error("Failed to run Java command at \(javaPath): \(error.localizedDescription)")
            return nil
        }
    }

    /// Ensures a Java runtime exists for the specified version, downloading if necessary.
    /// - Parameter version: The Java version component name.
    /// - Returns: The path to the Java executable, or an empty string if unavailable.
    func ensureJavaExists(version: String) async -> String {
        let existingPath = findJavaExecutable(version: version)
        if !existingPath.isEmpty {
            AppLog.game.info("Java version \(version) already exists")
            return existingPath
        }

        AppLog.game.info("Java version \(version) not found, starting download...")
        await DIContainer.shared.system.javaDownloadManager.downloadJavaRuntime(version: version)
        AppLog.game.info("Java version \(version) download completed")

        let newPath = findJavaExecutable(version: version)
        if newPath.isEmpty {
            AppLog.game.error("Java version \(version) download completed but still unable to find usable Java executable")
        }
        return newPath
    }

    func findDefaultJavaPath(for gameVersion: String) async -> String {
        do {
            let manifest = try await ModrinthService.fetchVersionInfo(from: gameVersion)
            let component = manifest.javaVersion.component

            return getJavaExecutablePath(version: component)
        } catch {
            AppLog.game.error("Failed to get game version info: \(error.localizedDescription)")
            return ""
        }
    }
}
