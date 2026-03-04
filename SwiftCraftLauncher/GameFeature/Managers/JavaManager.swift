import Foundation

/// Java管理器
class JavaManager {
    static let shared = JavaManager()

    private let fileManager = FileManager.default

    func getJavaExecutablePath(version: String) -> String {
        return AppPaths.javaExecutablePath(version: version)
    }

    func findJavaExecutable(version: String) -> String {
        let javaPath = getJavaExecutablePath(version: version)

        // 检查文件是否存在
        guard fileManager.fileExists(atPath: javaPath) else {
            return ""
        }

        // 验证Java是否能正常启动
        guard canJavaRun(at: javaPath) else {
            return ""
        }

        return javaPath
    }

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

    /// 获取指定 Java 可执行文件的 `java --version` 输出
    /// - Parameter javaPath: Java 可执行文件路径
    /// - Returns: 完整输出字符串（stdout + stderr），获取失败时返回 nil
    func getJavaVersionInfo(at javaPath: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: javaPath)
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard !data.isEmpty else { return nil }

            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            Logger.shared.error("获取 Java 版本信息失败: \(error.localizedDescription)")
            return nil
        }
    }

    // 检查Java是否存在，不存在则使用进度窗口下载
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

    func findDefaultJavaPath(for gameVersion: String) async -> String {
        do {
            // 查询缓存的版本文件获取manifest
            let manifest = try await ModrinthService.fetchVersionInfo(from: gameVersion)
            let component = manifest.javaVersion.component

            // 使用component拼接Java路径（不验证）
            return getJavaExecutablePath(version: component)
        } catch {
            Logger.shared.error("获取游戏版本信息失败: \(error.localizedDescription)")
            return ""
        }
    }
}
