//
//  JavaManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages local Java runtime installation, validation, and discovery.
class JavaManager {
    static let shared = JavaManager()

    private let fileManager = FileManager.default
    private let javaDownloadManager: JavaDownloadManager

    private init(javaDownloadManager: JavaDownloadManager = AppServices.javaDownloadManager) {
        self.javaDownloadManager = javaDownloadManager
    }

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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: javaPath)
        process.arguments = ["-version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let exitCode = process.terminationStatus
            if exitCode == 0 {
                Logger.shared.debug("Java启动验证成功: \(javaPath)")
                return true
            } else {
                Logger.shared.warning("Java启动验证失败，退出码: \(exitCode)")
                return false
            }
        } catch {
            Logger.shared.error("Java启动验证异常: \(error.localizedDescription)")
            return false
        }
    }

    /// Returns the output of `java --version` for the specified executable.
    /// - Parameter javaPath: The path to the Java executable.
    /// - Returns: The combined stdout and stderr output, or `nil` if execution fails.
    func getJavaVersionInfo(at javaPath: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: javaPath)
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard !data.isEmpty else { return nil }

            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            Logger.shared.error("获取 Java 版本信息失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// Ensures a Java runtime exists for the specified version, downloading if necessary.
    /// - Parameter version: The Java version component name.
    /// - Returns: The path to the Java executable, or an empty string if unavailable.
    func ensureJavaExists(version: String) async -> String {
        let existingPath = findJavaExecutable(version: version)
        if !existingPath.isEmpty {
            Logger.shared.info("Java版本 \(version) 已存在")
            return existingPath
        }

        Logger.shared.info("Java版本 \(version) 不存在，开始下载...")
        await javaDownloadManager.downloadJavaRuntime(version: version)
        Logger.shared.info("Java版本 \(version) 下载完成")

        let newPath = findJavaExecutable(version: version)
        if newPath.isEmpty {
            Logger.shared.error("Java版本 \(version) 下载完成后仍无法找到可用的Java可执行文件")
        }
        return newPath
    }

    func findDefaultJavaPath(for gameVersion: String) async -> String {
        do {
            let manifest = try await ModrinthService.fetchVersionInfo(from: gameVersion)
            let component = manifest.javaVersion.component

            return getJavaExecutablePath(version: component)
        } catch {
            Logger.shared.error("获取游戏版本信息失败: \(error.localizedDescription)")
            return ""
        }
    }
}
