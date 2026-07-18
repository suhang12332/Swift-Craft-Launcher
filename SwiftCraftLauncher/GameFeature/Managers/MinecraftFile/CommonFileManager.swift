//
//  CommonFileManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages common file operations for mod loader installations, including
/// Forge and Fabric JAR downloads and processor execution.
class CommonFileManager {
    let librariesDir: URL
    var onProgressUpdate: ((String, Int, Int) -> Void)?

    init(librariesDir: URL) {
        self.librariesDir = librariesDir
    }

    actor Counter {
        private var value = 0

        func increment() -> Int {
            value += 1
            return value
        }
    }

    /// Downloads Forge JAR files, handling errors silently.
    /// - Parameter libraries: The loader libraries to download.
    func downloadForgeJars(libraries: [ModrinthLoaderLibrary]) async {
        do {
            try await downloadForgeJarsThrowing(libraries: libraries)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to download Forge JAR file: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
        }
    }

    /// Downloads Forge JAR files.
    /// - Parameter libraries: The loader libraries to download.
    /// - Throws: A ``GlobalError`` if the download fails.
    func downloadForgeJarsThrowing(libraries: [ModrinthLoaderLibrary]) async throws {
        let tasks = libraries.compactMap { lib -> JarDownloadTask? in
            guard lib.downloadable else { return nil }

            // Prefer LibraryDownloads.artifact
            if let downloads = lib.downloads, let artifactUrl = downloads.artifact.url, let artifactPath = downloads.artifact.path {
                return JarDownloadTask(
                    name: lib.name,
                    url: artifactUrl,
                    destinationPath: artifactPath,
                    expectedSha1: downloads.artifact.sha1.isEmpty ? nil : downloads.artifact.sha1,
                )
            }

            guard let url = CommonService.mavenCoordinateToURL(lib: lib) else { return nil }
            return JarDownloadTask(
                name: lib.name,
                url: url,
                destinationPath: CommonService.mavenCoordinateToDefaultPath(lib.name),
                expectedSha1: nil,
            )
        }

        do {
            try await BatchJarDownloader.download(
                tasks: tasks,
                metaLibrariesDir: AppPaths.librariesDirectory,
                onProgressUpdate: onProgressUpdate,
            )
        } catch {
            let globalError = GlobalError.from(error)
            throw GlobalError.download(
                i18nKey: "error.download.jar_failed",
                level: .notification,
                message: "Failed to download Forge JAR files (\(tasks.count) tasks): \(globalError.localizedDescription)",
            )
        }
    }

    /// Downloads Fabric JAR files, handling errors silently.
    /// - Parameter libraries: The loader libraries to download.
    func downloadFabricJars(libraries: [ModrinthLoaderLibrary]) async {
        do {
            try await downloadFabricJarsThrowing(libraries: libraries)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to download JAR file: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
        }
    }

    /// Downloads Fabric JAR files.
    /// - Parameter libraries: The loader libraries to download.
    /// - Throws: A ``GlobalError`` if the download fails.
    func downloadFabricJarsThrowing(libraries: [ModrinthLoaderLibrary]) async throws {
        let tasks = libraries.compactMap { lib -> JarDownloadTask? in
            guard lib.downloadable else { return nil }
            guard let url = CommonService.mavenCoordinateToURL(lib: lib) else { return nil }
            return JarDownloadTask(
                name: lib.name,
                url: url,
                destinationPath: CommonService.mavenCoordinateToDefaultPath(lib.name),
                expectedSha1: "",
            )
        }

        do {
            try await BatchJarDownloader.download(
                tasks: tasks,
                metaLibrariesDir: AppPaths.librariesDirectory,
                onProgressUpdate: onProgressUpdate,
            )
        } catch {
            let globalError = GlobalError.from(error)
            throw GlobalError.download(
                i18nKey: "error.download.jar_failed",
                level: .notification,
                message: "Failed to download Fabric JAR files (\(tasks.count) tasks): \(globalError.localizedDescription)",
            )
        }
    }

    /// Executes client-side processors defined in the version manifest.
    /// - Parameters:
    ///   - processors: The list of processors to execute.
    ///   - librariesDir: The libraries directory URL.
    ///   - gameVersion: The Minecraft version string.
    ///   - data: Optional data fields for placeholder substitution.
    ///   - gameName: Optional game instance name.
    ///   - onProgressUpdate: Optional progress callback providing the message, current index, and total count.
    /// - Throws: A ``GlobalError`` if any processor fails.
    func executeProcessors(processors: [Processor], librariesDir: URL, gameVersion: String, data: [String: SidedDataEntry]? = nil, gameName: String? = nil, onProgressUpdate: ((String, Int, Int) -> Void)? = nil) async throws {
        // Filter client-side processors
        let clientProcessors = processors.filter { processor in
            guard let sides = processor.sides else { return true }
            return sides.contains(AppConstants.EnvironmentTypes.client)
        }

        guard !clientProcessors.isEmpty else {
            AppLog.game.info("No client-side processor found, skipping execution")
            return
        }

        AppLog.game.info("Found \(clientProcessors.count) client-side processor(s), starting execution")

        var processorData: [String: String] = [:]

        // Add base environment variables
        processorData["SIDE"] = AppConstants.EnvironmentTypes.client
        processorData["MINECRAFT_VERSION"] = gameVersion
        processorData["LIBRARY_DIR"] = librariesDir.path

        // Add Minecraft JAR path
        let minecraftJarPath = AppPaths.versionsDirectory.appendingPathComponent(gameVersion).appendingPathComponent("\(gameVersion).jar")
        processorData["MINECRAFT_JAR"] = minecraftJarPath.path

        // Add instance path (profile directory)
        if let gameName {
            processorData["ROOT"] = AppPaths.profileDirectory(gameName: gameName).path
        }

        // Parse data fields from version.json
        if let data {
            for (key, sidedEntry) in data {
                processorData[key] = Self.extractClientValue(from: sidedEntry.client) ?? sidedEntry.client
            }
        }

        let versionInfo = try await ModrinthService.fetchVersionInfo(from: gameVersion)
        let javaPath = await DIContainer.shared.system.javaManager.findJavaExecutable(version: versionInfo.javaVersion.component)

        for (index, processor) in clientProcessors.enumerated() {
            let processorName = String(describing: processor.jar)
            do {
                let message = String(format: "processor.executing".localized(), index + 1, clientProcessors.count, processorName)
                onProgressUpdate?(message, index + 1, clientProcessors.count)
                try await executeProcessor(
                    processor,
                    librariesDir: librariesDir,
                    gameVersion: gameVersion,
                    javaPath: javaPath,
                    data: processorData,
                    onProgressUpdate: onProgressUpdate,
                )
            } catch {
                AppLog.game.error("Failed to execute processor: \(error.localizedDescription)")
                throw GlobalError.download(
                    i18nKey: "error.download.processor_start_failed",
                    level: .notification,
                    message: "Failed to execute processor \(processorName) (index \(index + 1)/\(clientProcessors.count)): \(error.localizedDescription)",
                )
            }
        }
    }

    /// Executes a single processor.
    /// - Parameters:
    ///   - processor: The processor to execute.
    ///   - librariesDir: The libraries directory URL.
    ///   - gameVersion: The Minecraft version string.
    ///   - javaPath: The resolved path to the Java executable.
    ///   - data: Optional data fields for placeholder substitution.
    ///   - onProgressUpdate: Optional progress callback.
    /// - Throws: A ``GlobalError`` if the processor fails.
    private func executeProcessor(_ processor: Processor, librariesDir: URL, gameVersion: String, javaPath: String, data: [String: String]? = nil, onProgressUpdate _: ((String, Int, Int) -> Void)? = nil) async throws {
        try await ProcessorExecutor.executeProcessor(
            processor,
            librariesDir: librariesDir,
            gameVersion: gameVersion,
            javaPath: javaPath,
            data: data,
        )
    }

    /// Extracts client-side data from a sided data field value.
    /// - Parameter value: The data field value to parse.
    /// - Returns: The extracted client data, or `nil` if parsing fails.
    static func extractClientValue(from value: String) -> String? {
        // Convert Maven coordinate format to path
        if value.contains(":"), !value.hasPrefix("["), !value.hasPrefix("{") {
            return CommonService.convertMavenCoordinateToPath(value)
        }

        // Extract content from array format and convert to path
        if value.hasPrefix("["), value.hasSuffix("]") {
            let content = String(value.dropFirst().dropLast())
            if content.contains(":") {
                return CommonService.convertMavenCoordinateToPath(content)
            }
            return content
        }
        return value
    }
}
