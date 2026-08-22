//
//  MemoryPressureChecker.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Represents the macOS memory pressure level reported by the kernel.
enum MemoryPressureLevel {
    case normal
    case warning
    case critical

    /// Whether the system is under elevated memory pressure.
    var isElevated: Bool { self != .normal }

    var localizedMessage: String {
        switch self {
        case .normal: ""
        case .warning: "game_launch.memory_pressure.warning_message".localized()
        case .critical: "game_launch.memory_pressure.critical_message".localized()
        }
    }
}

/// Queries the macOS kernel for the current memory pressure level.
enum MemoryPressureChecker {
    /// Returns the current memory pressure level via `kern.memorystatus_vm_pressure_level`.
    static func check() -> MemoryPressureLevel {
        var value: UInt32 = 0
        var size = MemoryLayout<UInt32>.size
        let result = sysctlbyname("kern.memorystatus_vm_pressure_level", &value, &size, nil, 0)
        guard result == 0 else {
            AppLog.game.warning("Failed to query memory pressure level, sysctl returned \(result)")
            return .normal
        }
        switch value {
        case 2: return .warning
        case 4: return .critical
        default: return .normal
        }
    }
}

/// Reports the files and Java state that would prevent a reliable launch.
struct GameIntegrityReport {
    let errors: [GlobalError]

    var isValid: Bool { errors.isEmpty }

    var message: String {
        errors.map { $0.message ?? $0.localizedDescription }.joined(separator: "\n")
    }
}

/// Performs the minimum pre-launch integrity check and repair.
enum GameIntegrityChecker {
    static func check(game: GameVersionInfo) async -> GameIntegrityReport {
        do {
            let manifest = try await ModrinthService.fetchVersionInfo(from: game.gameVersion)
            var errors: [GlobalError] = []
            let javaManager = DIContainer.shared.system.javaManager

            if game.javaPath.isEmpty || !FileManager.default.isExecutableFile(atPath: game.javaPath) {
                errors.append(.gameLaunch(i18nKey: "game_launch.integrity.java_missing"))
            } else if !javaManager.canJavaRun(at: game.javaPath) {
                errors.append(.gameLaunch(i18nKey: "game_launch.integrity.java_unusable"))
            }

            let fileManager = MinecraftFileManager()
            await appendFileIssue(
                to: &errors,
                fileManager: fileManager,
                url: AppPaths.versionsDirectory
                    .appendingPathComponent(manifest.id)
                    .appendingPathComponent("\(manifest.id).jar"),
                expectedSha1: manifest.downloads.client.sha1,
                i18nKey: "game_launch.integrity.core_invalid",
                message: "game_launch.integrity.core_invalid".localized(),
            )

            for library in manifest.libraries where fileManager.shouldDownloadLibrary(library, minecraftVersion: manifest.id) {
                let artifact = library.downloads.artifact
                await appendFileIssue(
                    to: &errors,
                    fileManager: fileManager,
                    url: artifactURL(for: artifact, library: library),
                    expectedSha1: artifact.sha1,
                    i18nKey: "game_launch.integrity.library_invalid",
                    message: String(format: "game_launch.integrity.library_invalid".localized(), library.name),
                )

                if let classifiers = library.downloads.classifiers,
                   let nativePath = nativeArtifactPath(for: library, classifiers: classifiers, manifestId: manifest.id) {
                    await appendFileIssue(
                        to: &errors,
                        fileManager: fileManager,
                        url: nativePath.url,
                        expectedSha1: nativePath.sha1,
                        i18nKey: "game_launch.integrity.native_invalid",
                        message: String(format: "game_launch.integrity.native_invalid".localized(), library.name),
                    )
                }
            }

            return GameIntegrityReport(errors: errors)
        } catch {
            AppLog.game.error("Game integrity check failed: \(error.localizedDescription)")
            return GameIntegrityReport(
                errors: [.gameLaunch(i18nKey: "game_launch.integrity.check_failed", message: error.localizedDescription)],
            )
        }
    }

    static func repair(game: GameVersionInfo) async throws -> GameVersionInfo {
        let manifest = try await ModrinthService.fetchVersionInfo(from: game.gameVersion)
        let javaPath = await DIContainer.shared.system.javaManager.ensureJavaExists(
            version: manifest.javaVersion.component,
        )
        guard !javaPath.isEmpty else {
            throw GlobalError.configuration(
                i18nKey: "error.configuration.java_path_not_set",
                level: .popup,
                message: "Failed to repair Java runtime for version \(manifest.javaVersion.component)",
            )
        }

        try await MinecraftFileManager().downloadVersionFilesThrowing(
            manifest: manifest,
            gameName: game.gameName,
        )

        var repairedGame = game
        repairedGame.javaPath = javaPath
        repairedGame.javaVersion = manifest.javaVersion.majorVersion
        return repairedGame
    }

    private static func appendFileIssue(
        to errors: inout [GlobalError],
        fileManager: MinecraftFileManager,
        url: URL,
        expectedSha1: String,
        i18nKey: String,
        message: String,
    ) async {
        guard FileManager.default.fileExists(atPath: url.path) else {
            errors.append(.gameLaunch(i18nKey: i18nKey, message: "\(message) (\(url.path))"))
            return
        }
        do {
            guard try await fileManager.verifyExistingFile(at: url, expectedSha1: expectedSha1) else {
                errors.append(.gameLaunch(i18nKey: i18nKey, message: "\(message) (\(url.path))"))
                return
            }
        } catch {
            errors.append(.gameLaunch(i18nKey: i18nKey, message: "\(message) (\(url.path)): \(error.localizedDescription)"))
        }
    }

    private static func nativeArtifactPath(
        for library: Library,
        classifiers: [String: LibraryArtifact],
        manifestId: String,
    ) -> (url: URL, sha1: String)? {
        guard let natives = library.natives,
              let platformKey = natives.keys.first(where: { MacRuleEvaluator.isPlatformIdentifierSupported($0, minecraftVersion: manifestId) }),
              let classifierKey = natives[platformKey],
              let artifact = classifiers[classifierKey] else {
            return nil
        }
        return (artifactURL(for: artifact, library: library, root: AppPaths.nativesDirectory), artifact.sha1)
    }

    private static func artifactURL(
        for artifact: LibraryArtifact,
        library: Library,
        root: URL = AppPaths.librariesDirectory,
    ) -> URL {
        let path = artifact.path
            ?? CommonService.mavenCoordinateToRelativePath(library.name)
            ?? "\(library.name.replacingOccurrences(of: ":", with: "-")).jar"
        return path.hasPrefix("/") ? URL(fileURLWithPath: path) : root.appendingPathComponent(path)
    }
}
