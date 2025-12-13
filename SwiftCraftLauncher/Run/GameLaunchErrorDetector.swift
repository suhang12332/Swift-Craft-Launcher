import Foundation

/// 错误检测规则（macOS 平台专用）
enum ErrorRule: String, CaseIterable {
    // 图形相关错误（macOS 特定）
    case glOperationFailure = "1282: Invalid operation|Maybe try a lower resolution resourcepack\\?"
    case openglNotSupported = "The driver does not appear to support OpenGL"
    case graphicsDriver = "Couldn't set pixel format|org\\.lwjgl\\.LWJGLException"
    case macosFailedToFindServicePort = "java\\.lang\\.IllegalStateException: GLFW error before init: \\[0x10008\\]Cocoa: Failed to find service port for display"
    case resolutionTooHigh = "Maybe try a (lower resolution|lowerresolution) (resourcepack|texturepack)\\?"
    
    // 内存相关错误
    case outOfMemory = "java\\.lang\\.OutOfMemoryError|The system is out of physical RAM or swap space|Out of Memory Error|Error occurred during initialization of VM.*Too small maximum heap"
    case memoryExceeded = "There is insufficient memory for the Java Runtime Environment to continue"
    
    // 文件相关错误
    case fileChanged = "java\\.lang\\.SecurityException: SHA1 digest error for .*|signer information does not match signer information of other classes in the same package"
    case fileAlreadyExists = "java\\.nio\\.file\\.FileAlreadyExistsException: .*"
    case unsatisfiedLinkError = "java\\.lang\\.UnsatisfiedLinkError: Failed to locate library: .*"
    
    // 类加载错误
    case noSuchMethodError = "java\\.lang\\.NoSuchMethodError: .*"
    case noClassDefFoundError = "java\\.lang\\.NoClassDefFoundError: .*"
    case illegalAccessError = "java\\.lang\\.IllegalAccessError: tried to access class .* from class .*"
    
    // Mod 相关错误
    case duplicatedMod = "Found a duplicate mod .* at .*"
    case modResolution = "ModResolutionException: .*"
    case forgeModResolution = "Missing or unsupported mandatory dependencies:.*"
    case forgeFoundDuplicateMods = "Found duplicate mods:.*"
    case modResolutionConflict = "ModResolutionException: Found conflicting mods: .* conflicts with .*"
    case modResolutionMissing = "ModResolutionException: Could not find required mod: .* requires .*"
    case loadingCrashedForge = "LoaderExceptionModCrash: Caught exception from .*? \\(.*\\)"
    case bootstrapFailed = "Failed to create mod instance\\. ModID: .*?,"
    case loadingCrashedFabric = "Could not execute entrypoint stage '.*?' due to errors, provided by '.*'!"
    case modMixinFailure = "MixinApplyError|Mixin prepare failed |Mixin apply failed |mixin\\.injection\\.throwables\\."
    case mixinApplyModFailed = "Mixin apply for mod .* failed"
    case forgeError = "An exception was thrown, the game will display an error screen and halt\\."
    case optifineNotCompatibleWithForge = "java\\.lang\\.NoSuchMethodError: 'java\\.lang\\.Class sun\\.misc\\.Unsafe\\.defineAnonymousClass"
    case modFilesAreDecompressed = "The directories below appear to be extracted jar files\\. Fix this before you continue|Extracted mod jars found, loading will NOT continue"
    case optifineCausesWorldFailToLoad = "java\\.lang\\.NoSuchMethodError: net\\.minecraft\\.world\\.server\\.ChunkManager\\$ProxyTicketManager\\.shouldForceTicks"
    case tooManyModsExceedIdLimit = "maximum id range exceeded"
    case optifineRepeatInstallation = "ResolutionException: Module optifine reads another module named optifine"
    case shadersMod = "java\\.lang\\.RuntimeException: Shaders Mod detected\\. Please remove it, OptiFine has built-in support for shaders\\."
    
    // Forge 相关错误
    case incompleteForgeInstallation = "java\\.io\\.UncheckedIOException: java\\.io\\.IOException: Invalid paths argument, contained no existing paths: .*forge-.*-client\\.jar|Failed to find Minecraft resource version .* at .*forge-.*-client\\.jar|Cannot find launch target fmlclient"
    case forgeRepeatInstallation = "MultipleArgumentsForOptionException: Found multiple arguments for option .*?, but you asked for only one"
    case modlauncher8 = "java\\.lang\\.NoSuchMethodError: 'void sun\\.security\\.util\\.ManifestEntryVerifier\\.<init>\\(java\\.util\\.jar\\.Manifest\\)'"
    
    // 其他错误
    case debugCrash = "Manually triggered debug crash"
    case config = "Failed loading config file .*? of type .*? for modid .*"
    case fabricWarnings = "Warnings were found!|Incompatible mod set!|Incompatible mods found!"
    case entity = "Entity Type: .*"
    case block = "Block: .*"
    case installMixinBootstrap = "java\\.lang\\.ClassNotFoundException: org\\.spongepowered\\.asm\\.launch\\.MixinTweaker"
    case modName = "Invalid module name: '' is not a Java identifier"
    case nightConfigFixes = "com\\.electronwill\\.nightconfig\\.core\\.io\\.ParsingException: Not enough data available"
    
    var pattern: String {
        return self.rawValue
    }
    
    var description: String {
        switch self {
        case .glOperationFailure: return "OpenGL 操作失败"
        case .openglNotSupported: return "OpenGL 不支持"
        case .graphicsDriver: return "图形驱动问题"
        case .macosFailedToFindServicePort: return "macOS 显示服务端口错误"
        case .resolutionTooHigh: return "分辨率过高"
        case .outOfMemory: return "内存不足"
        case .memoryExceeded: return "内存超出限制"
        case .fileChanged: return "文件被修改"
        case .fileAlreadyExists: return "文件已存在"
        case .unsatisfiedLinkError: return "找不到原生库"
        case .noSuchMethodError: return "方法不存在"
        case .noClassDefFoundError: return "类定义未找到"
        case .illegalAccessError: return "非法访问错误"
        case .duplicatedMod: return "重复的 Mod"
        case .modResolution: return "Mod 解析错误"
        case .forgeModResolution: return "Forge Mod 依赖缺失"
        case .forgeFoundDuplicateMods: return "Forge 发现重复 Mod"
        case .modResolutionConflict: return "Mod 冲突"
        case .modResolutionMissing: return "Mod 依赖缺失"
        case .loadingCrashedForge: return "Forge Mod 加载崩溃"
        case .bootstrapFailed: return "Mod 初始化失败"
        case .loadingCrashedFabric: return "Fabric Mod 加载崩溃"
        case .modMixinFailure: return "Mixin 失败"
        case .mixinApplyModFailed: return "Mixin 应用失败"
        case .forgeError: return "Forge 错误"
        case .optifineNotCompatibleWithForge: return "OptiFine 与 Forge 不兼容"
        case .modFilesAreDecompressed: return "Mod 文件被解压"
        case .optifineCausesWorldFailToLoad: return "OptiFine 导致世界加载失败"
        case .tooManyModsExceedIdLimit: return "Mod 过多超出 ID 限制"
        case .optifineRepeatInstallation: return "OptiFine 重复安装"
        case .shadersMod: return "Shaders Mod 冲突"
        case .incompleteForgeInstallation: return "Forge 安装不完整"
        case .forgeRepeatInstallation: return "Forge 重复安装"
        case .modlauncher8: return "ModLauncher 8 错误"
        case .debugCrash: return "调试崩溃"
        case .config: return "配置文件加载失败"
        case .fabricWarnings: return "Fabric 警告"
        case .entity: return "实体错误"
        case .block: return "方块错误"
        case .installMixinBootstrap: return "Mixin 引导器缺失"
        case .modName: return "Mod 名称无效"
        case .nightConfigFixes: return "NightConfig 解析错误"
        }
    }
}

/// 游戏启动错误检测器
/// 用于检测游戏启动过程中的错误输出（即使进程没有崩溃）
class GameLaunchErrorDetector {
    static let shared = GameLaunchErrorDetector()
    
    /// 存储每个游戏的错误检测器，key 为游戏 ID
    private var detectors: [String: LaunchErrorMonitor] = [:]
    
    /// 存储已停止监控的游戏错误状态，key 为游戏 ID
    /// 用于在监控停止后仍能查询错误状态
    private var stoppedDetectorErrors: [String: Bool] = [:]
    
    /// 监控持续时间（秒），启动后这段时间内监控错误（10分钟）
    private let monitoringDuration: TimeInterval = 600.0
    
    private init() {}
    
    /// 开始监控游戏启动错误
    /// - Parameters:
    ///   - gameId: 游戏 ID
    ///   - process: 游戏进程
    func startMonitoring(gameId: String, process: Process) {
        // 如果已经有监控器在运行，先停止它
        stopMonitoring(gameId: gameId)
        
        // 创建新的监控器
        let monitor = LaunchErrorMonitor(gameId: gameId, process: process, duration: monitoringDuration)
        detectors[gameId] = monitor
        
        // 开始监控
        monitor.start()
        
        Logger.shared.info("开始监控游戏启动错误: \(gameId)")
    }
    
    /// 停止监控游戏启动错误
    /// - Parameter gameId: 游戏 ID
    func stopMonitoring(gameId: String) {
        guard let monitor = detectors[gameId] else {
            return
        }
        
        // 在停止监控前保存错误状态，以便后续查询
        let hasErrors = monitor.hasDetectedErrors
        stoppedDetectorErrors[gameId] = hasErrors
        
        monitor.stop()
        detectors.removeValue(forKey: gameId)
        Logger.shared.debug("停止监控游戏启动错误: \(gameId)，已检测到错误: \(hasErrors)")
    }
    
    /// 检查是否检测到了启动错误
    /// - Parameter gameId: 游戏 ID
    /// - Returns: 是否检测到了错误
    func hasDetectedErrors(gameId: String) -> Bool {
        // 优先检查正在运行的监控器
        if let monitor = detectors[gameId] {
            return monitor.hasDetectedErrors
        }
        // 如果监控器已停止，检查保存的错误状态
        return stoppedDetectorErrors[gameId] ?? false
    }
    
    /// 触发日志收集（在检测到错误时立即调用）
    /// - Parameter gameId: 游戏 ID
    func triggerLogCollection(gameId: String) {
        Task { @MainActor in
            await GameProcessManager.shared.collectLogsForGameImmediately(gameId: gameId)
        }
    }
    
    /// 清理所有监控器
    func cleanup() {
        for (gameId, _) in detectors {
            stopMonitoring(gameId: gameId)
        }
    }
    
    /// 清理已停止监控的游戏错误状态（在进程完全清理后调用）
    /// - Parameter gameId: 游戏 ID
    func cleanupErrorState(gameId: String) {
        stoppedDetectorErrors.removeValue(forKey: gameId)
    }
}

/// 单个游戏的启动错误监控器
private class LaunchErrorMonitor {
    let gameId: String
    let process: Process
    let duration: TimeInterval
    
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var outputHandle: FileHandle?
    private var errorHandle: FileHandle?
    private var monitoringTimer: Timer?
    private var startTime: Date?
    private var detectedErrors: [String] = []
    private var detectedRules: Set<ErrorRule> = []
    private var isMonitoring = false
    private var hasTriggeredLogCollection = false
    
    var hasDetectedErrors: Bool {
        return !detectedErrors.isEmpty
    }
    
    init(gameId: String, process: Process, duration: TimeInterval) {
        self.gameId = gameId
        self.process = process
        self.duration = duration
    }
    
    func start() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        startTime = Date()
        hasTriggeredLogCollection = false
        
        // 创建管道来捕获输出
        outputPipe = Pipe()
        errorPipe = Pipe()
        
        // 设置进程的输出管道
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // 获取文件句柄
        outputHandle = outputPipe?.fileHandleForReading
        errorHandle = errorPipe?.fileHandleForReading
        
        // 设置读取处理器
        setupOutputHandlers()
        
        // 设置定时器，在指定时间后停止监控（在主线程上）
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.monitoringTimer = Timer.scheduledTimer(withTimeInterval: self.duration, repeats: false) { [weak self] _ in
                self?.stopMonitoring()
            }
        }
        
        Logger.shared.debug("启动错误监控器已启动: \(gameId)，监控时长: \(duration)秒")
    }
    
    func stop() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        // 停止定时器
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // 清理文件句柄
        outputHandle?.readabilityHandler = nil
        errorHandle?.readabilityHandler = nil
        
        // 关闭管道
        outputHandle?.closeFile()
        errorHandle?.closeFile()
        
        outputHandle = nil
        errorHandle = nil
        outputPipe = nil
        errorPipe = nil
        
        Logger.shared.debug("启动错误监控器已停止: \(gameId)")
    }
    
    private func setupOutputHandlers() {
        // 统一的输出处理函数
        let processOutput: (FileHandle) -> Void = { [weak self] handle in
            guard let self = self, self.isMonitoring else { return }
            
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
            
            DispatchQueue.global(qos: .utility).async {
                self.processOutput(output)
            }
        }
        
        outputHandle?.readabilityHandler = processOutput
        errorHandle?.readabilityHandler = processOutput
    }
    
    private func processOutput(_ output: String) {
        // 累积所有输出用于完整匹配
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            // 只使用规则匹配
            if let matchedRule = matchErrorRule(in: trimmedLine) {
                // 避免重复报告相同的规则
                guard !detectedRules.contains(matchedRule) else { continue }
                
                detectedRules.insert(matchedRule)
                detectedErrors.append(trimmedLine)
                reportError(trimmedLine, rule: matchedRule)
            }
        }
    }
    
    /// 使用规则匹配错误
    private func matchErrorRule(in line: String) -> ErrorRule? {
        for rule in ErrorRule.allCases {
            do {
                let regex = try NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                if regex.firstMatch(in: line, options: [], range: range) != nil {
                    return rule
                }
            } catch {
                // 正则表达式编译失败，跳过
                continue
            }
        }
        return nil
    }
    
    /// 报告检测到的错误
    private func reportError(_ errorLine: String, rule: ErrorRule) {
        let elapsedTime = startTime.map { Date().timeIntervalSince($0) } ?? 0
        
        Logger.shared.warning("检测到游戏启动错误 [\(gameId)] (启动后 \(String(format: "%.1f", elapsedTime))秒) [\(rule.description)]: \(errorLine)")
        
        // 使用占位符格式，以便支持国际化
        let chineseMessageTemplate = "游戏启动错误: %@ - %@"
        let formattedChineseMessage = String(format: chineseMessageTemplate, rule.description, errorLine)
        
        let launchError = GlobalError.gameLaunch(
            chineseMessage: formattedChineseMessage,
            i18nKey: "error.game_launch.startup_error_detected",
            level: .silent
        )
        GlobalErrorHandler.shared.handle(launchError)
        
        // 第一次检测到错误时，立即触发日志收集（避免重复触发）
        if !hasTriggeredLogCollection {
            hasTriggeredLogCollection = true
            GameLaunchErrorDetector.shared.triggerLogCollection(gameId: gameId)
        }
    }
    
    /// 停止监控（内部方法，由定时器调用）
    private func stopMonitoring() {
        stop()
        
        if !detectedErrors.isEmpty {
            Logger.shared.warning("游戏启动错误监控结束 [\(gameId)]，共检测到 \(detectedErrors.count) 个错误")
        } else {
            Logger.shared.debug("游戏启动错误监控结束 [\(gameId)]，未检测到错误")
        }
    }
}

