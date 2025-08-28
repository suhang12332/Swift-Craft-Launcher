import Foundation
import ZIPFoundation

/// Forge/NeoForge Processor执行器
class ProcessorExecutor {

    /// 执行单个processor
    /// - Parameters:
    ///   - processor: 处理器配置
    ///   - librariesDir: 库目录
    ///   - gameVersion: 游戏版本（用于占位符替换）
    ///   - data: 数据字段，用于占位符替换
    /// - Throws: GlobalError 当处理失败时
    static func executeProcessor(
        _ processor: Processor,
        librariesDir: URL,
        gameVersion: String,
        data: [String: String]? = nil
    ) async throws {
        // 1. 验证和准备JAR文件
        let jarPath = try validateAndGetJarPath(
            processor.jar,
            librariesDir: librariesDir
        )

        // 2. 构建classpath
        let classpath = try buildClasspath(
            processor.classpath,
            jarPath: jarPath,
            librariesDir: librariesDir
        )

        // 3. 获取主类
        let mainClass = try getMainClassFromJar(jarPath: jarPath)

        // 4. 构建Java命令
        let command = buildJavaCommand(
            classpath: classpath,
            mainClass: mainClass,
            args: processor.args,
            gameVersion: gameVersion,
            librariesDir: librariesDir,
            data: data
        )

        // 5. 执行Java命令
        try await executeJavaCommand(command, workingDir: librariesDir)

        // 6. 处理输出文件
        if let outputs = processor.outputs {
            try await processOutputs(outputs, workingDir: librariesDir)
        }
    }

    // MARK: - Private Helper Methods

    private static func validateAndGetJarPath(_ jar: String?, librariesDir: URL)
        throws -> URL
    {
        guard let jar = jar else {
            throw GlobalError.validation(
                chineseMessage: "处理器缺少JAR文件配置",
                i18nKey: "error.validation.processor_missing_jar",
                level: .notification
            )
        }

        guard
            let relativePath = CommonService.mavenCoordinateToRelativePath(jar)
        else {
            throw GlobalError.validation(
                chineseMessage: "无效的Maven坐标: \(jar)",
                i18nKey: String(
                    format: "error.validation.invalid_maven_coordinate",
                    jar
                ),
                level: .notification
            )
        }

        let jarPath = librariesDir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: jarPath.path) else {
            throw GlobalError.resource(
                chineseMessage: "找不到处理器JAR文件: \(jar)",
                i18nKey: String(
                    format: "error.resource.processor_jar_not_found",
                    jar
                ),
                level: .notification
            )
        }

        return jarPath
    }

    private static func buildClasspath(
        _ processorClasspath: [String]?,
        jarPath: URL,
        librariesDir: URL
    ) throws -> [String] {
        var classpath: [String] = []

        if let processorClasspath = processorClasspath {
            for cp in processorClasspath {
                let cpPath =
                    cp.contains(":")
                    ? try getMavenPath(cp, librariesDir: librariesDir)
                    : librariesDir.appendingPathComponent(cp)

                if FileManager.default.fileExists(atPath: cpPath.path) {
                    classpath.append(cpPath.path)
                } else {
                    Logger.shared.warning("classpath文件不存在: \(cpPath.path)")
                }
            }
        }

        classpath.append(jarPath.path)

        return classpath
    }

    private static func getMavenPath(_ coordinate: String, librariesDir: URL)
        throws -> URL
    {
        // 使用支持@符号的方法来处理Maven坐标
        let relativePath: String

        if coordinate.contains("@") {
            // 对于包含@符号的坐标（如 org.ow2.asm:asm:9.3@jar），使用特殊处理方法
            relativePath = CommonService.parseMavenCoordinateWithAtSymbol(
                coordinate
            )
        } else {
            // 对于标准坐标，使用原有方法
            guard
                let path = CommonService.mavenCoordinateToRelativePath(
                    coordinate
                )
            else {
                throw GlobalError.validation(
                    chineseMessage: "无效的Maven坐标: \(coordinate)",
                    i18nKey: String(
                        format: "error.validation.invalid_maven_coordinate",
                        coordinate
                    ),
                    level: .notification
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
        data: [String: String]?
    ) -> [String] {
        var command = ["-cp", classpath.joined(separator: ":")]
        command.append(mainClass)

        if let args = args {
            let processedArgs = args.map { arg in
                processPlaceholders(
                    CommonFileManager.extractClientValue(from: arg)!,
                    gameVersion: gameVersion,
                    librariesDir: librariesDir,
                    data: data
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
        data: [String: String]?
    ) -> String {
        var processedArg = arg

        // 基础占位符替换
        let basicReplacements = [
            "{SIDE}": "client",
            "{VERSION}": gameVersion,
            "{VERSION_NAME}": gameVersion,
            "{LIBRARY_DIR}": librariesDir.path,
            "{WORKING_DIR}": librariesDir.path,
        ]

        for (placeholder, value) in basicReplacements {
            processedArg = processedArg.replacingOccurrences(
                of: placeholder,
                with: value
            )
        }

        // 处理data字段的占位符替换
        if let data = data {
            for (key, value) in data {
                let placeholder = "{\(key)}"
                if processedArg.contains(placeholder) {
                    let replacementValue =
                        value.contains(":") && !value.hasPrefix("/")
                        ? (CommonFileManager.extractClientValue(from: value).map
                        { librariesDir.appendingPathComponent($0).path }
                            ?? value)
                        : value

                    processedArg = processedArg.replacingOccurrences(
                        of: placeholder,
                        with: replacementValue
                    )
                }
            }
        }

        return processedArg
    }

    private static func executeJavaCommand(_ command: [String], workingDir: URL)
        async throws
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/java")
        process.arguments = command
        process.currentDirectoryURL = workingDir

        // 设置环境变量
        var environment = ProcessInfo.processInfo.environment
        environment["LIBRARY_DIR"] = workingDir.path
        process.environment = environment

        // 捕获输出
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()

            // 实时读取输出
            setupOutputHandlers(outputPipe: outputPipe, errorPipe: errorPipe)

            process.waitUntilExit()

            // 清理handlers
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil

            if process.terminationStatus != 0 {
                throw GlobalError.download(
                    chineseMessage:
                        "处理器执行失败 (退出码: \(process.terminationStatus))",
                    i18nKey: "error.download.processor_execution_failed",
                    level: .notification
                )
            }
        } catch {
            throw GlobalError.download(
                chineseMessage: "启动处理器失败: \(error.localizedDescription)",
                i18nKey: "error.download.processor_start_failed",
                level: .notification
            )
        }
    }

    private static func setupOutputHandlers(outputPipe: Pipe, errorPipe: Pipe) {
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, String(data: data, encoding: .utf8) != nil {
                // 输出数据已读取，防止管道阻塞
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, String(data: data, encoding: .utf8) != nil {
                // 错误输出数据已读取，防止管道阻塞
            }
        }
    }

    private static func processOutputs(
        _ outputs: [String: String],
        workingDir: URL
    ) async throws {
        let fileManager = FileManager.default

        for (source, destination) in outputs {
            let sourceURL = workingDir.appendingPathComponent(source)
            let destURL = workingDir.appendingPathComponent(destination)

            // 确保目标目录存在
            try fileManager.createDirectory(
                at: destURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            // 移动或复制文件
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
                chineseMessage: "无法打开JAR文件: \(jarPath.lastPathComponent)",
                i18nKey: "error.download.jar_open_failed",
                level: .notification
            )
        }

        guard let manifestEntry = archive["META-INF/MANIFEST.MF"] else {
            throw GlobalError.download(
                chineseMessage:
                    "无法从processor JAR文件中获取主类: \(jarPath.lastPathComponent)",
                i18nKey: "error.download.processor_main_class_not_found",
                level: .notification
            )
        }

        var manifestData = Data()
        _ = try archive.extract(manifestEntry) { data in
            manifestData.append(data)
        }

        guard let manifestContent = String(data: manifestData, encoding: .utf8)
        else {
            throw GlobalError.download(
                chineseMessage: "无法解析MANIFEST.MF内容",
                i18nKey: "error.download.manifest_parse_failed",
                level: .notification
            )
        }

        // 解析MANIFEST.MF查找Main-Class
        let lines = manifestContent.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("Main-Class:") {
                let mainClass = trimmedLine.dropFirst("Main-Class:".count)
                    .trimmingCharacters(in: .whitespaces)
                return mainClass
            }
        }

        throw GlobalError.download(
            chineseMessage:
                "无法从processor JAR文件中获取主类: \(jarPath.lastPathComponent)",
            i18nKey: "error.download.processor_main_class_not_found",
            level: .notification
        )
    }
}
