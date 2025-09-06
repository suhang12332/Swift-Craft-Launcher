import Foundation
import SwiftUI

/// Java版本信息
struct JavaVersionInfo: Identifiable, Hashable, Sendable {
    let id = UUID()
    let version: String
    let majorVersion: Int
    let path: String
    let displayName: String
    init(version: String, path: String) {
        self.version = version
        self.path = path
        // 解析主版本号
        let components = version.components(separatedBy: ".")
        if let firstComponent = components.first, let major = Int(firstComponent) {
            self.majorVersion = major
        } else {
            // 处理类似 "1.8.0_292" 的格式
            if version.hasPrefix("1.") && components.count > 1 {
                self.majorVersion = 8 // Java 8
            } else {
                self.majorVersion = 0
            }
        }
        // 生成显示名称
        if majorVersion >= 9 {
            self.displayName = "Java \(majorVersion)"
        } else {
            self.displayName = "Java 8"
        }
    }
}

/// Java版本管理器
class JavaVersionManager: ObservableObject {
    static let shared = JavaVersionManager()
    @Published var allJavaVersions: [JavaVersionInfo] = []
    @Published var isScanning = false
    @Published var showMinorVersions = false

    private init() {
        // 从用户设置中读取是否显示小版本
        self.showMinorVersions = UserDefaults.standard.bool(forKey: "showMinorVersions")
        // 异步扫描Java版本
        Task {
            await scanJavaVersions()
        }
    }
    /// 扫描系统中的Java版本
    func scanJavaVersions() async {
        await MainActor.run {
            isScanning = true
        }
        var javaVersions: [JavaVersionInfo] = []
        // 使用 java_home -V 命令扫描所有Java版本
        if let output = try? await shell(["/usr/libexec/java_home", "-V"]) {
            let lines = output.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if let verRange = trimmed.range(of: "^[^,]+", options: String.CompareOptions.regularExpression),
                   let pathRange = trimmed.range(of: "/Library/Java/JavaVirtualMachines/.*", options: String.CompareOptions.regularExpression) {
                    let version = String(trimmed[verRange])
                    let path = String(trimmed[pathRange]) + "/bin"
                    let javaInfo = JavaVersionInfo(version: version, path: path)
                    // 仅添加可用的 Java，可执行文件存在才加入列表
                    if JavaVersionChecker.shared.isValidJavaPath(javaInfo.path) {
                        javaVersions.append(javaInfo)
                    } else {
                        // print("Filtered invalid Java path: \(javaInfo.path)")
                    }
                }
            }
        }
        
        // 按主版本号排序，相同主版本号按完整版本号排序
        javaVersions.sort { first, second in
            if first.majorVersion != second.majorVersion {
                return first.majorVersion > second.majorVersion
            }
            return first.version > second.version
        }
        await MainActor.run {
            self.allJavaVersions = javaVersions
            self.isScanning = false
        }
    }
    
    var displayJavaVersions: [JavaVersionInfo] {
        if showMinorVersions {
            return allJavaVersions
        } else {
            // 只显示每个主版本号的最新版本
            var majorVersions: [Int: JavaVersionInfo] = [:]
            for javaInfo in allJavaVersions {
                if majorVersions[javaInfo.majorVersion] == nil {
                    majorVersions[javaInfo.majorVersion] = javaInfo
                }
            }
            
            return majorVersions.values.sorted { $0.majorVersion > $1.majorVersion }
        }
    }
    
    /// 根据游戏版本自动匹配Java版本
    func getRecommendedJavaVersion(for gameVersion: String) -> JavaVersionInfo? {
        // 解析Minecraft版本号
        let components = gameVersion.components(separatedBy: ".")
        guard let major = Int(components[0]), let minor = Int(components[1]) else {
            return nil
        }
        
        // 根据Minecraft版本确定推荐的Java版本
        let recommendedMajorVersion: Int
        if major == 1 && minor <= 12 {
            recommendedMajorVersion = 8
        } else if major == 1 && minor <= 16 {
            recommendedMajorVersion = 16
        } else if major == 1 && minor <= 17 {
            recommendedMajorVersion = 17
        } else if major == 1 && minor <= 20 {
            recommendedMajorVersion = 17
        } else {
            // 1.21+ 推荐Java 21
            recommendedMajorVersion = 21
        }
        
        // 查找匹配的Java版本
        let matchingVersions = allJavaVersions.filter { $0.majorVersion == recommendedMajorVersion }
        
        if let exactMatch = matchingVersions.first {
            return exactMatch
        }
        
        // 如果没有精确匹配，查找兼容的版本
        if recommendedMajorVersion == 8 {
            // Java 8 兼容性
            return allJavaVersions.first { $0.majorVersion >= 8 && $0.majorVersion <= 11 }
        } else if recommendedMajorVersion == 17 {
            // Java 17 兼容性
            return allJavaVersions.first { $0.majorVersion >= 17 && $0.majorVersion <= 21 }
        } else if recommendedMajorVersion == 21 {
            // Java 21 兼容性
            return allJavaVersions.first { $0.majorVersion >= 21 }
        }
        // 返回最新的Java版本作为备选
        return allJavaVersions.first
    }
    /// 设置是否显示小版本
    func setShowMinorVersions(_ show: Bool) {
        showMinorVersions = show
        UserDefaults.standard.set(show, forKey: "showMinorVersions")
    }
    /// 执行shell命令
    private func shell(_ args: [String]) async throws -> String {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        let timeout: TimeInterval = 30.0
        try task.run()
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
                DispatchQueue.global(qos: .userInitiated).async {
                    task.waitUntilExit()
                    timeoutTimer.cancel()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                }
            }
        }
    }
}
