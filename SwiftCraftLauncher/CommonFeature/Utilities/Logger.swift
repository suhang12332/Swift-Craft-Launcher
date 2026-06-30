//
//  Logger.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

/// Provides unified logging to both the system log and a daily rotating file.
import Foundation
import os.log
import AppKit

class Logger: AppLogging {
    static let shared = Logger()
    private let logger = OSLog(
        subsystem: Bundle.main.identifier,
        category: Bundle.main.appCategory
    )

    private var logFileHandle: FileHandle?
    private let logQueue = DispatchQueue(label: AppConstants.logTag, qos: .utility)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private var logFileURL: URL? {
        let logsDirectory = AppPaths.logsDirectory
        let appName = Bundle.main.appName.replacingOccurrences(of: " ", with: "-").lowercased()
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        return logsDirectory.appendingPathComponent("\(appName)-\(today).log")
    }

    private init() {
        cleanupOldLogs()
        setupLogFile()
    }

    deinit {
        closeLogFile()
    }

    private func setupLogFile() {
        guard let logURL = logFileURL else { return }

        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }

        do {
            logFileHandle = try FileHandle(forWritingTo: logURL)
            logFileHandle?.seekToEndOfFile()

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

    private func writeToLogFile(_ message: String) {
        logQueue.async {
            self.checkAndSwitchLogFile()

            let timestamp = self.dateFormatter.string(from: Date())
            let logEntry = "[\(timestamp)] \(message)\n"

            if let data = logEntry.data(using: .utf8) {
                self.logFileHandle?.write(data)
                self.logFileHandle?.synchronizeFile()
            }
        }
    }

    private func checkAndSwitchLogFile() {
        guard let currentLogURL = logFileURL else { return }

        if let currentHandle = logFileHandle {
            if currentHandle.fileDescriptor != -1 {
                let expectedFileName = currentLogURL.lastPathComponent
                let currentFileName = currentLogURL.lastPathComponent

                if expectedFileName != currentFileName {
                    switchToNewLogFile()
                }
            }
        } else {
            setupLogFile()
        }
    }

    private func switchToNewLogFile() {
        closeLogFile()
        setupLogFile()

        let switchMessage = "=== Log file switched at \(dateFormatter.string(from: Date())) ===\n"
        if let data = switchMessage.data(using: .utf8) {
            logFileHandle?.write(data)
        }
    }

    func logDebug(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line) {
        log(items, type: .debug, prefix: "🔍", file: file, function: function, line: line)
    }

    func logInfo(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line) {
        log(items, type: .info, prefix: "ℹ️", file: file, function: function, line: line)
    }
    func logWarning(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line) {
        log(items, type: .default, prefix: "⚠️", file: file, function: function, line: line)
    }
    func logError(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line) {
        log(items, type: .error, prefix: "❌", file: file, function: function, line: line)
    }

    fileprivate func log(
        _ items: [Any],
        type: OSLogType,
        prefix: String,
        file: String,
        function: String,
        line: Int
    ) {
        let fileName = (file as NSString).lastPathComponent
        let message = NSMutableString()
        for (index, item) in items.enumerated() {
            if index > 0 {
                message.append(" ")
            }
            message.append(Self.stringify(item))
        }
        let logMessage = "\(prefix) [\(fileName):\(line)] \(function): \(message)"

        os_log("%{public}@", log: logger, type: type, logMessage)

        writeToLogFile(logMessage)
    }

    /// Returns the path to the current log file.
    func getLogFilePath() -> String? {
        return logFileURL?.path
    }

    /// Returns metadata about the current log file.
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

    /// Removes log files older than seven days.
    func manualCleanup() {
        cleanupOldLogs()
    }

    /// Opens the current log file in the default system application.
    func openLogFile() {
        guard let logURL = logFileURL else {
            Self.shared.error("无法获取日志文件路径")
            return
        }

        if FileManager.default.fileExists(atPath: logURL.path) {
            NSWorkspace.shared.open(logURL)
        } else {
            do {
                try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: Date())

                try "日志文件已创建 - \(dateString)".write(to: logURL, atomically: true, encoding: .utf8)
                NSWorkspace.shared.open(logURL)
            } catch {
                Self.shared.error("无法创建或打开日志文件: \(error)")
            }
        }
    }

    /// Removes log files older than seven days.
    func cleanupOldLogs() {
        logQueue.async {
            let calendar = Calendar.current
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

            let logsDirectory = AppPaths.logsDirectory
            self.cleanupLogsInDirectory(logsDirectory, sevenDaysAgo: sevenDaysAgo)
        }
    }

    private func cleanupLogsInDirectory(_ directory: URL, sevenDaysAgo: Date) {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return
        }

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )

            for fileURL in fileURLs where fileURL.pathExtension == "log" {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let creationDate = attributes[.creationDate] as? Date,
                   creationDate < sevenDaysAgo {
                    try FileManager.default.removeItem(at: fileURL)
                }
            }
        } catch {
            Self.shared.error("Failed to cleanup old logs in \(directory.path): \(error)")
        }
    }

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
            let maxElements = 100
            let result = NSMutableString()
            result.append("[")

            for (index, element) in array.prefix(maxElements).enumerated() {
                if index > 0 {
                    result.append(", ")
                }
                result.append(stringify(element))
            }

            if array.count > maxElements {
                result.append(", ... (\(array.count - maxElements) more)]")
            } else {
                result.append("]")
            }
            return result as String
        case let dict as [String: Any]:
            let maxEntries = 50
            let result = NSMutableString()
            result.append("{")
            var entryIndex = 0

            for (key, value) in dict {
                if entryIndex >= maxEntries {
                    result.append(", ... (\(dict.count - maxEntries) more)")
                    break
                }
                if entryIndex > 0 {
                    result.append(", ")
                }
                result.append("\(key): ")
                result.append(stringify(value))
                entryIndex += 1
            }
            result.append("}")
            return result as String
        case let codable as Encodable:
            let encoder = JSONEncoder()
            encoder.outputFormatting = []
            if let data = try? encoder.encode(AnyEncodable(codable)),
               let json = String(data: data, encoding: .utf8) {
                let maxLength = 1000
                if json.count > maxLength {
                    return String(json.prefix(maxLength)) + "... (truncated)"
                }
                return json
            }
            return "\(codable)"
        default:
            return String(describing: value)
        }
    }
}

private struct AnyEncodable: Encodable {

    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        _encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
