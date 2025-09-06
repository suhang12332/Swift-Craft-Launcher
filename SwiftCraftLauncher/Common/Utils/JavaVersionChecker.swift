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
    func checkJavaVersion(
        at path: String,
        completion: @escaping (JavaVersionResult) -> Void
    ) {
        guard !path.isEmpty else {
            let result = JavaVersionResult(
                version: "java.version.not_detected".localized(),
                error: nil
            )
            completion(result)
            return
        }
        // Resolve executable path robustly
        guard let javaPath = resolveJavaExecutable(from: path) else {
            let error = "Java 可执行文件不存在: \(path)"
            let result = JavaVersionResult(
                version: "java.version.not_detected".localized(),
                error: error
            )
            GlobalErrorHandler.shared.handle(
                GlobalError.configuration(
                    chineseMessage: error,
                    i18nKey: "error.configuration.java_executable_not_found",
                    level: .notification
                )
            )
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
                let version =
                    output.components(separatedBy: .newlines).first {
                        $0.contains("version")
                    } ?? output

                DispatchQueue.main.async {
                    if version.contains("version") {
                        if let match = version.split(separator: "\"")
                            .dropFirst().first {
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
                        GlobalErrorHandler.shared.handle(
                            GlobalError.validation(
                                chineseMessage: error,
                                i18nKey:
                                    "error.validation.java_version_unrecognized",
                                level: .silent
                            )
                        )
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
                    GlobalErrorHandler.shared.handle(
                        GlobalError.configuration(
                            chineseMessage: error,
                            i18nKey:
                                "error.configuration.java_version_detection_failed",
                            level: .notification
                        )
                    )
                    completion(result)
                }
            }
        }
    }

    /// 检查 Java 版本（异步版本）
    /// - Parameter path: Java 安装路径
    /// - Returns: 检测结果
    /// - Throws: GlobalError 当操作失败时
    func checkJavaVersionAsync(at path: String) async throws
        -> JavaVersionResult {
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
        guard let _ = resolveJavaExecutable(from: path) else { return false }
        return true
    }

    /// 获取 Java 可执行文件路径
    /// - Parameter path: Java 安装路径
    /// - Returns: Java 可执行文件路径
    func getJavaExecutablePath(from path: String) -> String {
        return resolveJavaExecutable(from: path) ?? ""
    }

    /// 尝试解析并返回可用的 Java 可执行文件路径。
    /// 支持常见 JDK 布局（例如 Azul/Zulu 11/17）。
    private func resolveJavaExecutable(from rawPath: String) -> String? {
        guard !rawPath.isEmpty else { return nil }
        let fm = FileManager.default

        // 规范化路径
        var base = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        base = base.replacingOccurrences(of: "/Llbrary/", with: "/Library/")
        base = (base as NSString).standardizingPath

        // 备选候选列表（按优先级）
        var candidates: [String] = []

        // 如果传入的是到 bin 目录
        if base.hasSuffix("/bin") {
            candidates.append((base as NSString).appendingPathComponent("java"))
        }

        // 如果传入的是到 Contents/Home
        if base.hasSuffix("/Contents/Home") {
            candidates.append(((base as NSString).appendingPathComponent("bin") as NSString).appendingPathComponent("java"))
        }

        // 如果传入的是 JDK/JRE 根目录（以 .jdk 或 .jre 结尾）
        if base.hasSuffix(".jdk") || base.hasSuffix(".jre") {
            let contentsHome = ((base as NSString).appendingPathComponent("Contents") as NSString).appendingPathComponent("Home")
            candidates.append(((contentsHome as NSString).appendingPathComponent("bin") as NSString).appendingPathComponent("java"))
        }

        // Azul/Zulu 通常位于 .../zulu-<ver>.jdk/Contents/Home 或 Home/bin
        if base.contains("/JavaVirtualMachines/") {
            let contentsHome = ((base as NSString).appendingPathComponent("Contents") as NSString).appendingPathComponent("Home")
            let zuluBinJava = (((contentsHome as NSString).appendingPathComponent("bin") as NSString).appendingPathComponent("java"))
            candidates.append(zuluBinJava)
        }

        // 如果传入已经是 Home/bin 目录
        if base.hasSuffix("/Home/bin") {
            candidates.append((base as NSString).appendingPathComponent("java"))
        }

        // 通用尝试：直接认为传入的是到 Home 目录
        let homeBinJava = (((base as NSString).appendingPathComponent("bin") as NSString).appendingPathComponent("java"))
        candidates.append(homeBinJava)

        // 去重保序
        var seen = Set<String>()
        candidates = candidates.filter { seen.insert($0).inserted }

        // 返回首个存在的可执行文件
        for cand in candidates {
            if fm.fileExists(atPath: cand) {
                return cand
            }
        }
        return nil
    }
}
