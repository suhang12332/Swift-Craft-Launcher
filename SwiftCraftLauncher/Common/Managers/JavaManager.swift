import Foundation

/// Java管理器
class JavaManager {
    static let shared = JavaManager()

    private let fileManager = FileManager.default

    func findJavaExecutable(version: String) -> String {
        let javaPath = AppPaths.runtimeDirectory.appendingPathComponent(version).appendingPathComponent("jre.bundle/Contents/Home/bin/java")

        // 检查文件是否存在
        guard fileManager.fileExists(atPath: javaPath.path) else {
            return ""
        }

        // 验证Java是否能正常启动
        guard canJavaRun(at: javaPath.path) else {
            return ""
        }

        return javaPath.path
    }

    /// 验证Java是否能正常启动
    /// - Parameter javaPath: Java可执行文件路径
    /// - Returns: 是否能正常启动
    func canJavaRun(at javaPath: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: javaPath)
        process.arguments = ["-version"]

        // 设置输出管道以捕获输出
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            // 检查退出状态
            let exitCode = process.terminationStatus
            if exitCode == 0 {
                Logger.shared.debug("Java启动验证成功: \(javaPath)")
                return true
            } else {
                Logger.shared.warning("Java启动验证失败，退出码: \(exitCode)")
                return false
            }
        } catch {
            Logger.shared.error("Java启动验证异常: \(error.localizedDescription)")
            return false
        }
    }

    /// 检查Java是否存在，如果不存在则使用进度窗口下载，并返回Java路径
    /// - Parameter version: Java版本
    /// - Returns: Java可执行文件路径（可能为空字符串，表示失败）
    func ensureJavaExists(version: String) async -> String {
        // 优先使用已经存在并且可运行的 Java
        let existingPath = findJavaExecutable(version: version)
        if !existingPath.isEmpty {
            Logger.shared.info("Java版本 \(version) 已存在")
            return existingPath
        }

        // 如果不存在，则使用进度窗口下载Java运行时
        Logger.shared.info("Java版本 \(version) 不存在，开始下载...")
        await JavaDownloadManager.shared.downloadJavaRuntime(version: version)
        Logger.shared.info("Java版本 \(version) 下载完成")

        // 下载完成后再次尝试获取 Java 路径
        let newPath = findJavaExecutable(version: version)
        if newPath.isEmpty {
            Logger.shared.error("Java版本 \(version) 下载完成后仍无法找到可用的Java可执行文件")
        }
        return newPath
    }
}
