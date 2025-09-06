import Foundation
import SwiftUI

class GameSettingsManager: ObservableObject {
    @Published var allJavaPaths: [String: String] = [:]
    
    // 使用新的Java版本管理器
    @Published var javaVersionManager = JavaVersionManager.shared

    private static func detectJavaPath() async -> String {
        // 尝试使用 java_home 命令获取 JAVA_HOME 路径
        if let taskOutput = try? await shell(["/usr/libexec/java_home"]) {
            let javaHome = taskOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !javaHome.isEmpty {
                return javaHome + "/bin"
            }
        }
        // 备用方案：使用 which 命令查找 java 可执行文件
        if let taskOutput = try? await shell(["which", "java"]) {
            let javaBin = taskOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !javaBin.isEmpty {
                let javaDir = (javaBin as NSString).deletingLastPathComponent
                return javaDir
            }
        }
        // 如果都找不到，返回默认路径
        return "/usr/bin"
    }

    private static func detectAllJavaPaths() async -> [String: String] {
        var dict: [String: String] = [:]
        guard let output = try? await shell(["/usr/libexec/java_home", "-V"]) else { return dict }

        // 解析 java_home -V 的输出，格式如下：
        // Matching Java Virtual Machines (2):
        //     17.0.2, x86_64:   "OpenJDK 17.0.2" /Library/Java/JavaVirtualMachines/temurin-17.0.2.jdk/Contents/Home
        //     1.8.0_292, x86_64:    "AdoptOpenJDK 8" /Library/Java/JavaVirtualMachines/adoptopenjdk-8.jdk/Contents/Home

        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // 使用正则表达式匹配版本号和路径
            if let verRange = trimmed.range(of: "^[^,]+", options: .regularExpression),
               let pathRange = trimmed.range(of: "/Library/Java/JavaVirtualMachines/.*", options: .regularExpression) {
                let version = String(trimmed[verRange])
                let path = String(trimmed[pathRange]) + "/bin"
                dict[version] = path
            }
        }
        return dict
    }

    private static func shell(_ args: [String]) async throws -> String {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        // 设置命令执行超时时间（30秒）
        let timeout: TimeInterval = 30.0

        try task.run()

        // 使用 async/await 和 continuation 模式处理异步执行
        return try await withCheckedThrowingContinuation { continuation in
            // 在后台队列中监控任务执行，使用 userInitiated QoS 避免优先级反转
            DispatchQueue.global(qos: .userInitiated).async {
                // 设置超时定时器
                let timeoutTimer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
                timeoutTimer.schedule(deadline: .now() + timeout)
                timeoutTimer.setEventHandler {
                    if task.isRunning {
                        task.terminate()
                        let taskError = GlobalError.configuration(
                            chineseMessage: "Shell 命令执行超时，已等待 \(timeout) 秒",
                            i18nKey: "error.configuration.shell_timeout",
                            level: .notification
                        )
                        continuation.resume(throwing: taskError)
                    }
                }
                timeoutTimer.resume()

                // 监控任务完成状态
                DispatchQueue.global(qos: .userInitiated).async {
                    task.waitUntilExit()

                    // 取消超时定时器
                    timeoutTimer.cancel()

                    // 读取命令输出
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                }
            }
        }
    }

    // MARK: - 单例实例
    static let shared = GameSettingsManager()

    // MARK: - 应用设置属性
    @AppStorage("defaultJavaPath")
    var defaultJavaPath: String = "/usr/bin" {
        didSet { objectWillChange.send() }
    }

    @AppStorage("concurrentDownloads")
    var concurrentDownloads: Int = 64 {
        didSet {
            if concurrentDownloads < 1 {
                concurrentDownloads = 1
            }
            objectWillChange.send()
        }
    }

    @AppStorage("autoDownloadDependencies")
    var autoDownloadDependencies: Bool = false {
        didSet { objectWillChange.send() }
    }

    @AppStorage("minecraftVersionManifestURL")
    var minecraftVersionManifestURL: String = "https://launchermeta.mojang.com/mc/game/version_manifest.json" {
        didSet { objectWillChange.send() }
    }

    @AppStorage("modrinthAPIBaseURL")
    var modrinthAPIBaseURL: String = "https://api.modrinth.com/v2" {
        didSet { objectWillChange.send() }
    }

    @AppStorage("forgeMavenMirrorURL")
    var forgeMavenMirrorURL: String = "" {
        didSet { objectWillChange.send() }
    }

    @AppStorage("gitProxyURL")
    var gitProxyURL: String = "https://ghfast.top" {
        didSet { objectWillChange.send() }
    }

    @AppStorage("globalXms")
    var globalXms: Int = 512 {
        didSet { objectWillChange.send() }
    }

    @AppStorage("globalXmx")
    var globalXmx: Int = 4096 {
        didSet { objectWillChange.send() }
    }

    /// 计算系统最大可用内存分配（基于物理内存的70%）
    var maximumMemoryAllocation: Int {
        let physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        let physicalMemoryMB = physicalMemoryBytes / 1_048_576
        let calculatedMax = Int(Double(physicalMemoryMB) * 0.7)
        let roundedMax = (calculatedMax / 512) * 512
        return max(roundedMax, 512)
    }

    private init() {
        // 首先使用默认值初始化
        self.allJavaPaths = [:]

        // 然后异步加载实际的 Java 路径信息
        Task {
            await loadJavaPaths()
        }
    }

    private func loadJavaPaths() async {
        // 异步检测所有可用的 Java 路径
        let javaPaths = await Self.detectAllJavaPaths()
        let javaPath = await Self.detectJavaPath()

        // 在主线程上更新 UI 相关属性
        await MainActor.run {
            self.allJavaPaths = javaPaths
            if self.defaultJavaPath == "/usr/bin" {
                self.defaultJavaPath = javaPath
            }
        }
    }
}
