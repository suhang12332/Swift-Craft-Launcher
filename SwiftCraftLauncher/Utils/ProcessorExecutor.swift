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
        guard let jar = processor.jar else {
            throw GlobalError.validation(
                chineseMessage: "处理器缺少JAR文件配置",
                i18nKey: "error.validation.processor_missing_jar",
                level: .notification
            )
        }
        
        // 1. 找到processor的JAR文件
        guard let relativePath = CommonService.mavenCoordinateToRelativePath(jar) else {
            throw GlobalError.validation(
                chineseMessage: "无效的Maven坐标: \(jar)",
                i18nKey: "error.validation.invalid_maven_coordinate",
                level: .notification
            )
        }
        let jarPath = librariesDir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: jarPath.path) else {
            throw GlobalError.resource(
                chineseMessage: "找不到处理器JAR文件: \(jar)",
                i18nKey: "error.resource.processor_jar_not_found",
                level: .notification
            )
        }
        
        // 2. 构建classpath
        var classpath: [String] = []  // 初始化为空数组
        if let processorClasspath = processor.classpath {
            for cp in processorClasspath {
                let cpPath: URL
                if cp.contains(":") {
                    // 这是Maven坐标，需要转换为路径
                    guard let relativePath = CommonService.mavenCoordinateToRelativePath(cp) else {
                        Logger.shared.warning("跳过无效的classpath坐标: \(cp)")
                        continue
                    }
                    cpPath = librariesDir.appendingPathComponent(relativePath)
                } else {
                    // 这已经是相对路径
                    cpPath = librariesDir.appendingPathComponent(cp)
                }
                
                if FileManager.default.fileExists(atPath: cpPath.path) {
                    classpath.append(cpPath.path)
                } else {
                    Logger.shared.warning("classpath文件不存在: \(cpPath.path)")
                }
            }
        }
        
        // 添加processor的主JAR文件到classpath
        classpath.append(jarPath.path)
        Logger.shared.info("Processor classpath: \(classpath.joined(separator: ":"))")
        
        // 3. 构建Java命令
        var command = ["-cp", classpath.joined(separator: ":")]
        
        // 获取processor的主类
        let mainClass = try getMainClassFromJar(jarPath: jarPath)
        guard let mainClass = mainClass else {
            throw GlobalError.download(
                chineseMessage: "无法从processor JAR文件中获取主类: \(jarPath.lastPathComponent)",
                i18nKey: "error.download.processor_main_class_not_found",
                level: .notification
            )
        }
        
        // 添加主类
        command.append(mainClass)
        Logger.shared.info("使用主类执行processor: \(mainClass)")
        
        Logger.shared.info("使用-cp方式执行processor")
        
        // 添加处理器参数
        if let args = processor.args {
            Logger.shared.info("开始处理processor参数")
            
            let processedArgs = args.map { arg in
                var processedArg = arg
                
                // 基础占位符替换
                processedArg = processedArg.replacingOccurrences(of: "{SIDE}", with: "client")
                    .replacingOccurrences(of: "{VERSION}", with: gameVersion)
                    .replacingOccurrences(of: "{VERSION_NAME}", with: gameVersion)
                    .replacingOccurrences(of: "{LIBRARY_DIR}", with: librariesDir.path)
                    .replacingOccurrences(of: "{WORKING_DIR}", with: librariesDir.path)
                
                // 处理data字段的占位符替换
                if let data = data {
                    for (key, value) in data {
                        let placeholder = "{\(key)}"
                        if processedArg.contains(placeholder) {
                            // 如果值是Maven坐标，转换为文件路径
                            let replacementValue: String
                            if value.contains(":") && !value.hasPrefix("/") {
                                // 这是Maven坐标，需要转换为路径
                                if let relativePath = CommonService.mavenCoordinateToRelativePath(value) {
                                    replacementValue = librariesDir.appendingPathComponent(relativePath).path
                                    Logger.shared.info("转换Maven坐标 \(value) -> \(replacementValue)")
                                } else {
                                    replacementValue = value
                                    Logger.shared.warning("无法转换Maven坐标: \(value)")
                                }
                            } else {
                                replacementValue = value
                            }
                            
                            processedArg = processedArg.replacingOccurrences(of: placeholder, with: replacementValue)
                            Logger.shared.info("替换占位符 \(placeholder) -> \(replacementValue)")
                        }
                    }
                } else {
                    Logger.shared.warning("没有data字段，无法进行占位符替换")
                }
                
                return processedArg
            }
            command.append(contentsOf: processedArgs)
        }
        
        Logger.shared.info("完整Java命令: \(command.joined(separator: " "))")
        Logger.shared.info("工作目录: \(librariesDir.path)")
        Logger.shared.info("库目录: \(librariesDir.path)")
        Logger.shared.info("Processor JAR路径: \(jarPath.path)")
        Logger.shared.info("Processor配置: jar=\(processor.jar ?? "nil"), sides=\(processor.sides ?? []), args=\(processor.args ?? [])")
        Logger.shared.info("Processor classpath: \(processor.classpath ?? [])")
        Logger.shared.info("Processor outputs: \(processor.outputs ?? [:])")
        Logger.shared.info("Classpath字符串: \(classpath.joined(separator: ":"))")
        
        // 4. 执行Java命令
        let process = Process()
        
        // 直接使用java命令
        process.executableURL = URL(fileURLWithPath: "/usr/bin/java")
        process.arguments = command
        process.currentDirectoryURL = librariesDir
        
        // 设置环境变量
        var environment = ProcessInfo.processInfo.environment
        environment["LIBRARY_DIR"] = librariesDir.path
        process.environment = environment
        
        // 捕获输出
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // 打印完整的Java命令（包括java可执行文件）
        let fullCommand = ["/usr/bin/java"] + command
        Logger.shared.info("执行处理器命令: \(fullCommand.joined(separator: " "))")
        
        do {
            try process.run()
            
            // 实时读取输出
            let outputHandle = outputPipe.fileHandleForReading
            let errorHandle = errorPipe.fileHandleForReading
            
            // 设置输出读取
            outputHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let output = String(data: data, encoding: .utf8) {
                        Logger.shared.info("处理器输出: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                    }
                }
            }
            
            // 设置错误输出读取
            errorHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let errorOutput = String(data: data, encoding: .utf8) {
                        Logger.shared.warning("处理器错误输出: \(errorOutput.trimmingCharacters(in: .whitespacesAndNewlines))")
                    }
                }
            }
            
            process.waitUntilExit()
            
            // 清理handlers
            outputHandle.readabilityHandler = nil
            errorHandle.readabilityHandler = nil
            
            if process.terminationStatus != 0 {
                Logger.shared.error("处理器执行失败，退出码: \(process.terminationStatus)")
                throw GlobalError.download(
                    chineseMessage: "处理器执行失败 (退出码: \(process.terminationStatus))",
                    i18nKey: "error.download.processor_execution_failed",
                    level: .notification
                )
            }
            
            Logger.shared.info("处理器执行成功，退出码: \(process.terminationStatus)")
            
            // 5. 处理输出文件（如果需要）
            if let outputs = processor.outputs {
                try await processOutputs(outputs, workingDir: librariesDir)
            }
            
        } catch {
            Logger.shared.error("启动处理器失败: \(error.localizedDescription)")
            throw GlobalError.download(
                chineseMessage: "启动处理器失败: \(error.localizedDescription)",
                i18nKey: "error.download.processor_start_failed",
                level: .notification
            )
        }
    }
    
    /// 处理输出文件
    /// - Parameters:
    ///   - outputs: 输出文件映射
    ///   - workingDir: 工作目录
    /// - Throws: GlobalError 当处理失败时
    private static func processOutputs(_ outputs: [String: String], workingDir: URL) async throws {
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
    
    /// 从JAR文件中解析MANIFEST.MF获取主类
    /// - Parameter jarPath: JAR文件路径
    /// - Returns: 主类名，如果没有则返回nil
    /// - Throws: GlobalError 当解析失败时
    private static func getMainClassFromJar(jarPath: URL) throws -> String? {
        guard let archive = Archive(url: jarPath, accessMode: .read) else {
            throw GlobalError.download(
                chineseMessage: "无法打开JAR文件: \(jarPath.lastPathComponent)",
                i18nKey: "error.download.jar_open_failed",
                level: .notification
            )
        }
        
        // 查找MANIFEST.MF文件
        guard let manifestEntry = archive["META-INF/MANIFEST.MF"] else {
            Logger.shared.warning("JAR文件中没有找到MANIFEST.MF")
            return nil
        }
        
        // 读取MANIFEST.MF内容
        var manifestData = Data()
        _ = try archive.extract(manifestEntry) { data in
            manifestData.append(data)
        }
        
        guard let manifestContent = String(data: manifestData, encoding: .utf8) else {
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
                let mainClass = trimmedLine.dropFirst("Main-Class:".count).trimmingCharacters(in: .whitespaces)
                Logger.shared.info("从MANIFEST.MF解析到主类: \(mainClass)")
                return mainClass
            }
        }
        
        Logger.shared.warning("MANIFEST.MF中没有找到Main-Class")
        return nil
    }
}
