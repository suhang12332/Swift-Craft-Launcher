import Foundation
import os.log
import AppKit

class Logger { // swiftlint:disable:this type_body_length
    static let shared = Logger()
    private let logger = OSLog(
        subsystem: Bundle.main.identifier,
        category: Bundle.main.appCategory
    )

    // 文件日志相关属性
    private var logFileHandle: FileHandle?
    private let logQueue = DispatchQueue(label: AppConstants.logTag, qos: .utility)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    // 日志文件路径
    private var logFileURL: URL? {
        // 获取应用名称，移除空格并转换为小写
        let appName = Bundle.main.appName.replacingOccurrences(of: " ", with: "-").lowercased()

        // 优先使用系统推荐的日志目录
        if let logsDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let appLogsDirectory = logsDirectory.appendingPathComponent("Logs", isDirectory: true)
                .appendingPathComponent(Bundle.main.appName, isDirectory: true)

            // 确保logs目录存在
            try? FileManager.default.createDirectory(at: appLogsDirectory, withIntermediateDirectories: true)

            // 使用应用名称-日期格式作为文件名
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let today = dateFormatter.string(from: Date())
            return appLogsDirectory.appendingPathComponent("\(appName)-\(today).log")
        }

        let logsDirectory = AppPaths.launcherSupportDirectory.appendingPathComponent("logs", isDirectory: true)

        // 确保logs目录存在
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        // 使用应用名称-日期格式作为文件名
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        return logsDirectory.appendingPathComponent("\(appName)-\(today).log")
    }

    private init() {
        // 启动时清理旧日志文件
        cleanupOldLogs()
        setupLogFile()
    }

    deinit {
        closeLogFile()
    }

    // MARK: - 文件日志设置

    private func setupLogFile() {
        guard let logURL = logFileURL else { return }

        // 如果文件不存在，创建文件
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }

        // 打开文件句柄
        do {
            logFileHandle = try FileHandle(forWritingTo: logURL)
            // 移动到文件末尾
            logFileHandle?.seekToEndOfFile()

            // 写入启动日志
            let startupMessage = "=== Launcher Started at \(dateFormatter.string(from: Date())) ===\n"
            if let data = startupMessage.data(using: .utf8) {
                logFileHandle?.write(data)
            }
        } catch {
            Self.shared.error("Failed to setup log file: \(error)")
        }
    }

    private func closeLogFile() {
        logFileHandle?.closeFile()
        logFileHandle = nil
    }

    // MARK: - 写入日志文件

    private func writeToLogFile(_ message: String) {
        logQueue.async {
            // 检查是否需要切换到新的日志文件（日期变化）
            self.checkAndSwitchLogFile()

            let timestamp = self.dateFormatter.string(from: Date())
            let logEntry = "[\(timestamp)] \(message)\n"

            if let data = logEntry.data(using: .utf8) {
                self.logFileHandle?.write(data)
                // 强制同步到磁盘
                self.logFileHandle?.synchronizeFile()
            }
        }
    }

    // MARK: - 日志文件切换

    private func checkAndSwitchLogFile() {
        guard let currentLogURL = logFileURL else { return }

        // 检查当前文件句柄是否指向正确的文件
        if let currentHandle = logFileHandle {
            // 如果文件句柄存在但指向的文件路径不匹配，需要切换
            if currentHandle.fileDescriptor != -1 {
                // 检查文件路径是否匹配当前日期
                let expectedFileName = currentLogURL.lastPathComponent
                let currentFileName = currentLogURL.lastPathComponent

                if expectedFileName != currentFileName {
                    // 日期变化，切换到新文件
                    switchToNewLogFile()
                }
            }
        } else {
            // 文件句柄不存在，重新设置
            setupLogFile()
        }
    }

    private func switchToNewLogFile() {
        // 关闭当前文件句柄
        closeLogFile()

        // 设置新的日志文件
        setupLogFile()

        // 记录文件切换日志
        let switchMessage = "=== Log file switched at \(dateFormatter.string(from: Date())) ===\n"
        if let data = switchMessage.data(using: .utf8) {
            logFileHandle?.write(data)
        }
    }

    // MARK: - Public Logging Methods

    func debug(
        _ items: Any...,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            items,
            type: .debug,
            prefix: "🔍",
            file: file,
            function: function,
            line: line
        )
    }

    func info(
        _ items: Any...,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            items,
            type: .info,
            prefix: "ℹ️",
            file: file,
            function: function,
            line: line
        )
    }

    func warning(
        _ items: Any...,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            items,
            type: .default,
            prefix: "⚠️",
            file: file,
            function: function,
            line: line
        )
    }

    func error(
        _ items: Any...,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            items,
            type: .error,
            prefix: "❌",
            file: file,
            function: function,
            line: line
        )
    }

    // MARK: - Core Logging

    private func log(
        _ items: [Any],
        type: OSLogType,
        prefix: String,
        file: String,
        function: String,
        line: Int
    ) {
        let fileName = (file as NSString).lastPathComponent
        let message = items.map { Logger.stringify($0) }.joined(separator: " ")
        let logMessage = "\(prefix) [\(fileName):\(line)] \(function): \(message)"

        // 输出到控制台。 本地调试可以开启
        os_log("%{public}@", log: logger, type: type, logMessage)

        // 写入到文件
        writeToLogFile(logMessage)
    }

    // MARK: - 日志文件管理

    /// 获取日志文件路径
    func getLogFilePath() -> String? {
        return logFileURL?.path
    }

    /// 获取当前日志文件信息
    func getCurrentLogInfo() -> (path: String, fileName: String, date: String)? {
        guard let logURL = logFileURL else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())

        return (
            path: logURL.path,
            fileName: logURL.lastPathComponent,
            date: today
        )
    }

    /// 手动触发日志清理
    func manualCleanup() {
        cleanupOldLogs()
    }

    /// 打开当前日志文件
    func openLogFile() {
        guard let logURL = logFileURL else {
            Logger.shared.error("无法获取日志文件路径")
            return
        }

        // 检查文件是否存在
        if FileManager.default.fileExists(atPath: logURL.path) {
            // 使用系统默认应用打开日志文件
            NSWorkspace.shared.open(logURL)
        } else {
            // 如果日志文件不存在，创建并打开
            do {
                // 确保目录存在
                try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)

                // 创建日志文件
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: Date())

                try "日志文件已创建 - \(dateString)".write(to: logURL, atomically: true, encoding: .utf8)
                NSWorkspace.shared.open(logURL)
            } catch {
                Logger.shared.error("无法创建或打开日志文件: \(error)")
            }
        }
    }

    /// 清理旧日志文件（保留最近7天的日志）
    func cleanupOldLogs() {
        logQueue.async {
            let calendar = Calendar.current
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

            // 清理系统日志目录
            if let logsDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
                let appLogsDirectory = logsDirectory.appendingPathComponent("Logs", isDirectory: true)
                    .appendingPathComponent(Bundle.main.appName, isDirectory: true)
                self.cleanupLogsInDirectory(appLogsDirectory, sevenDaysAgo: sevenDaysAgo)
            }
        }
    }

    private func cleanupLogsInDirectory(_ directory: URL, sevenDaysAgo: Date) {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )

            for fileURL in fileURLs {
                if fileURL.pathExtension == "log" {
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    if let creationDate = attributes[.creationDate] as? Date,
                       creationDate < sevenDaysAgo {
                        try FileManager.default.removeItem(at: fileURL)
                    }
                }
            }
        } catch {
            Logger.shared.error("Failed to cleanup old logs in \(directory.path): \(error)")
        }
    }

    // MARK: - Stringify Helper

    static func stringify(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let int as Int:
            return String(int)
        case let double as Double:
            return String(double)
        case let bool as Bool:
            return String(bool)
        case let error as Error:
            return "Error: \(error.localizedDescription)"
        case let data as Data:
            return String(data: data, encoding: .utf8) ?? "<Data>"
        case let array as [Any]:
            return "[" + array.map { stringify($0) }.joined(separator: ", ")
            + "]"
        case let dict as [String: Any]:
            return dict.map { "\($0): \(stringify($1))" }.joined(
                separator: ", "
            )
        case let codable as Encodable:
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(AnyEncodable(codable)),
               let json = String(data: data, encoding: .utf8)
            {
                return json
            }
            return "\(codable)"
        default:
            return String(describing: value)
        }
    }
}

// Helper for encoding any Encodable
private struct AnyEncodable: Encodable {

    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        _encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
