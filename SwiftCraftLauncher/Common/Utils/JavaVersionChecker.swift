import Foundation

/// Java 版本检测结果
struct JavaVersionResult {
    let version: String
    let error: String?
    let isValid: Bool
    
    init(version: String, error: String? = nil) {
        self.version = version
        self.error = error
        self.isValid = error == nil
    }
}

/// Java 版本检测工具类
class JavaVersionChecker {
    static let shared = JavaVersionChecker()
    
    private init() {}
    
    /// 检查 Java 版本
    /// - Parameters:
    ///   - path: Java 安装路径
    ///   - completion: 完成回调，返回检测结果
    func checkJavaVersion(at path: String, completion: @escaping (JavaVersionResult) -> Void) {
        guard !path.isEmpty else {
            let result = JavaVersionResult(
                version: "java.version.not_detected".localized(),
                error: nil
            )
            completion(result)
            return
        }

        let javaPath = path + "/java"
        guard FileManager.default.fileExists(atPath: javaPath) else {
            let error = "Java 可执行文件不存在: \(javaPath)"
            let result = JavaVersionResult(
                version: "java.version.not_detected".localized(),
                error: error
            )
            GlobalErrorHandler.shared.handle(GlobalError.configuration(
                chineseMessage: error,
                i18nKey: "error.configuration.java_executable_not_found",
                level: .notification
            ))
            completion(result)
            return
        }

        DispatchQueue.global().async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: javaPath)
            process.arguments = ["-version"]
            let pipe = Pipe()
            process.standardError = pipe
            process.standardOutput = nil
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let version = output.components(separatedBy: .newlines).first(where: { $0.contains("version") }) ?? output
                
                DispatchQueue.main.async {
                    if version.contains("version") {
                        if let match = version.split(separator: "\"").dropFirst().first {
                            let result = JavaVersionResult(version: "\(match)")
                            completion(result)
                        } else {
                            let result = JavaVersionResult(version: version)
                            completion(result)
                        }
                    } else {
                        let error = "无法识别 Java 版本输出: \(version)"
                        let result = JavaVersionResult(
                            version: "java.version.unrecognized".localized(),
                            error: error
                        )
                        GlobalErrorHandler.shared.handle(GlobalError.validation(
                            chineseMessage: error,
                            i18nKey: "error.validation.java_version_unrecognized",
                            level: .silent
                        ))
                        completion(result)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    let error = "Java 版本检测失败: \(error.localizedDescription)"
                    let result = JavaVersionResult(
                        version: "java.version.detection_failed".localized(),
                        error: error
                    )
                    GlobalErrorHandler.shared.handle(GlobalError.configuration(
                        chineseMessage: error,
                        i18nKey: "error.configuration.java_version_detection_failed",
                        level: .notification
                    ))
                    completion(result)
                }
            }
        }
    }
    
    /// 检查 Java 版本（异步版本）
    /// - Parameter path: Java 安装路径
    /// - Returns: 检测结果
    /// - Throws: GlobalError 当操作失败时
    func checkJavaVersionAsync(at path: String) async throws -> JavaVersionResult {
        return await withCheckedContinuation { continuation in
            checkJavaVersion(at: path) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    /// 验证 Java 路径是否有效
    /// - Parameter path: Java 安装路径
    /// - Returns: 是否有效
    func isValidJavaPath(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        let javaPath = path + "/java"
        return FileManager.default.fileExists(atPath: javaPath)
    }
    
    /// 获取 Java 可执行文件路径
    /// - Parameter path: Java 安装路径
    /// - Returns: Java 可执行文件路径
    func getJavaExecutablePath(from path: String) -> String {
        return path.isEmpty ? "" : path + "/java"
    }
} 