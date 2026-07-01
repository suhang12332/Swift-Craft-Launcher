//
//  ProcessorExecutor.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import ZIPFoundation

/// Executes Forge/NeoForge processor configurations by invoking Java.
enum ProcessorExecutor {
    /// Executes a single processor configuration.
    /// - Parameters:
    ///   - processor: The processor configuration to execute.
    ///   - librariesDir: The directory containing library dependencies.
    ///   - gameVersion: The game version string used for placeholder substitution.
    ///   - javaPath: The path to the Java executable.
    ///   - data: Optional data fields used for placeholder substitution.
    /// - Throws: A ``GlobalError`` if processing fails.
    static func executeProcessor(
        _ processor: Processor,
        librariesDir: URL,
        gameVersion: String,
        javaPath: String,
        data: [String: String]? = nil,
    ) async throws {
        let jarPath = try validateAndGetJarPath(
            processor.jar,
            librariesDir: librariesDir,
        )

        let classpath = try buildClasspath(
            processor.classpath,
            jarPath: jarPath,
            librariesDir: librariesDir,
        )

        let mainClass = try getMainClassFromJar(jarPath: jarPath)

        let command = buildJavaCommand(
            classpath: classpath,
            mainClass: mainClass,
            args: processor.args,
            gameVersion: gameVersion,
            librariesDir: librariesDir,
            data: data,
        )

        try await executeJavaCommand(command, javaPath: javaPath, workingDir: librariesDir)

        if let outputs = processor.outputs {
            try await processOutputs(outputs, workingDir: librariesDir)
        }
    }

    private static func validateAndGetJarPath(
        _ jar: String?,
        librariesDir: URL,
    ) throws -> URL {
        guard let jar else {
            throw GlobalError.validation(
                i18nKey: "error.validation.processor_missing_jar",
                level: .notification,
            )
        }

        guard
            let relativePath = CommonService.mavenCoordinateToRelativePath(jar)
        else {
            throw GlobalError.validation(
                i18nKey: String(
                    format: "error.validation.invalid_maven_coordinate",
                    jar,
                ),
                level: .notification,
            )
        }

        let jarPath = librariesDir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: jarPath.path) else {
            throw GlobalError.resource(
                i18nKey: String(
                    format: "error.resource.processor_jar_not_found",
                    jar,
                ),
                level: .notification,
            )
        }

        return jarPath
    }

    private static func buildClasspath(
        _ processorClasspath: [String]?,
        jarPath: URL,
        librariesDir: URL,
    ) throws -> [String] {
        var classpath: [String] = []

        if let processorClasspath {
            for cp in processorClasspath {
                let cpPath =
                    cp.contains(":")
                    ? try getMavenPath(cp, librariesDir: librariesDir)
                    : librariesDir.appendingPathComponent(cp)

                if FileManager.default.fileExists(atPath: cpPath.path) {
                    classpath.append(cpPath.path)
                } else {
                    AppLog.game.error("classpath file does not exist: \(cpPath.path)")
                }
            }
        }

        classpath.append(jarPath.path)

        return classpath
    }

    private static func getMavenPath(
        _ coordinate: String,
        librariesDir: URL,
    ) throws -> URL {
        let relativePath: String

        if coordinate.contains("@") {
            relativePath = CommonService.parseMavenCoordinateWithAtSymbol(
                coordinate,
            )
        } else {
            guard
                let path = CommonService.mavenCoordinateToRelativePath(
                    coordinate,
                )
            else {
                throw GlobalError.validation(
                    i18nKey: String(
                        format: "error.validation.invalid_maven_coordinate",
                        coordinate,
                    ),
                    level: .notification,
                )
            }
            relativePath = path
        }

        return librariesDir.appendingPathComponent(relativePath)
    }

    private static func buildJavaCommand(
        classpath: [String],
        mainClass: String,
        args: [String]?,
        gameVersion: String,
        librariesDir: URL,
        data: [String: String]?,
    ) -> [String] {
        var command = ["-cp", classpath.joined(separator: ":")]
        command.append(mainClass)

        if let args {
            let processedArgs: [String] = args.compactMap { arg in
                guard let extractedValue = CommonFileManager.extractClientValue(from: arg) else {
                    AppLog.game.error("Unable to extract client value: \(arg)")
                    return nil
                }
                return processPlaceholders(
                    extractedValue,
                    gameVersion: gameVersion,
                    librariesDir: librariesDir,
                    data: data,
                )
            }
            command.append(contentsOf: processedArgs)
        }

        return command
    }

    private static func processPlaceholders(
        _ arg: String,
        gameVersion: String,
        librariesDir: URL,
        data: [String: String]?,
    ) -> String {
        guard arg.contains("{") else {
            return arg
        }

        let processedArg = NSMutableString(string: arg)

        let basicReplacements = [
            AppConstants.ProcessorPlaceholders.side: AppConstants.EnvironmentTypes.client,
            AppConstants.ProcessorPlaceholders.version: gameVersion,
            AppConstants.ProcessorPlaceholders.versionName: gameVersion,
            AppConstants.ProcessorPlaceholders.libraryDir: librariesDir.path,
            AppConstants.ProcessorPlaceholders.workingDir: librariesDir.path,
        ]

        for (placeholder, value) in basicReplacements where processedArg.range(of: placeholder).location != NSNotFound {
            processedArg.replaceOccurrences(
                of: placeholder,
                with: value,
                options: [],
                range: NSRange(location: 0, length: processedArg.length),
            )
        }

        if let data {
            for (key, value) in data {
                let placeholder = "{\(key)}"
                if processedArg.range(of: placeholder).location != NSNotFound {
                    let replacementValue =
                        value.contains(":") && !value.hasPrefix("/")
                    ? (
                        CommonFileManager.extractClientValue(from: value).map {
                            librariesDir.appendingPathComponent($0).path
                        } ?? value) : value

                    processedArg.replaceOccurrences(
                        of: placeholder,
                        with: replacementValue,
                        options: [],
                        range: NSRange(location: 0, length: processedArg.length),
                    )
                }
            }
        }

        return processedArg as String
    }

    private static func executeJavaCommand(
        _ command: [String],
        javaPath: String,
        workingDir: URL,
    ) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: javaPath)
        process.arguments = command
        process.currentDirectoryURL = workingDir

        var environment = ProcessInfo.processInfo.environment
        environment["LIBRARY_DIR"] = workingDir.path
        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()

            setupOutputHandlers(outputPipe: outputPipe, errorPipe: errorPipe)

            process.waitUntilExit()

            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil

            if process.terminationStatus != 0 {
                throw GlobalError.download(
                    i18nKey: "error.download.processor_execution_failed",
                    level: .notification,
                )
            }
        } catch {
            throw GlobalError.download(
                i18nKey: "error.download.processor_start_failed",
                level: .notification,
            )
        }
    }

    private static func setupOutputHandlers(outputPipe: Pipe, errorPipe: Pipe) {
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, String(data: data, encoding: .utf8) != nil { }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, String(data: data, encoding: .utf8) != nil { }
        }
    }

    private static func processOutputs(
        _ outputs: [String: String],
        workingDir: URL,
    ) async throws {
        let fileManager = FileManager.default

        for (source, destination) in outputs {
            let sourceURL = workingDir.appendingPathComponent(source)
            let destURL = workingDir.appendingPathComponent(destination)

            try fileManager.createDirectory(
                at: destURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )

            if fileManager.fileExists(atPath: sourceURL.path) {
                try fileManager.moveItem(at: sourceURL, to: destURL)
            }
        }
    }

    private static func getMainClassFromJar(jarPath: URL) throws -> String {
        let archive: Archive
        do {
            archive = try Archive(url: jarPath, accessMode: .read)
        } catch {
            throw GlobalError.download(
                i18nKey: "error.download.jar_open_failed",
                level: .notification,
            )
        }

        guard let manifestEntry = archive["META-INF/MANIFEST.MF"] else {
            throw GlobalError.download(
                i18nKey: "error.download.processor_main_class_not_found",
                level: .notification,
            )
        }

        var manifestData = Data()
        _ = try archive.extract(manifestEntry) { data in
            manifestData.append(data)
        }

        guard let manifestContent = String(data: manifestData, encoding: .utf8)
        else {
            throw GlobalError.download(
                i18nKey: "error.download.manifest_parse_failed",
                level: .notification,
            )
        }

        let lines = manifestContent.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("Main-Class:") {
                return trimmedLine.dropFirst("Main-Class:".count)
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        throw GlobalError.download(
            i18nKey: "error.download.processor_main_class_not_found",
            level: .notification,
        )
    }
}
