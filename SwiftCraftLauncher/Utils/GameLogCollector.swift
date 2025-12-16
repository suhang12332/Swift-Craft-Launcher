import Foundation
import SwiftUI

/// 游戏日志收集器
/// 用于收集游戏文件夹中的崩溃日志和日志文件，并发送到 AI 窗口
@MainActor
class GameLogCollector {
    static let shared = GameLogCollector()

    private init() {}

    /// 收集游戏日志并打开 AI 窗口
    /// - Parameter gameName: 游戏名称
    func collectAndOpenAIWindow(gameName: String) async {
        // 收集日志文件
        let logFiles = await collectLogFiles(gameName: gameName)

        if logFiles.isEmpty {
            // 没有找到日志文件
            let error = GlobalError.fileSystem(
                chineseMessage: "未找到游戏日志文件",
                i18nKey: "error.filesystem.logs_not_found",
                level: .notification
            )
            GlobalErrorHandler.shared.handle(error)
            return
        }

        // 打开 AI 窗口并发送日志
        await openAIWindowWithLogs(logFiles: logFiles, gameName: gameName)
    }

    /// 收集日志文件
    /// - Parameter gameName: 游戏名称
    /// - Returns: 日志文件 URL 数组
    private func collectLogFiles(gameName: String) async -> [URL] {
        let gameDirectory = AppPaths.profileDirectory(gameName: gameName)
        let fileManager = FileManager.default

        // 1. 优先收集崩溃报告文件夹中的所有文件
        let crashReportsDir = gameDirectory.appendingPathComponent("crash-reports", isDirectory: true)

        if fileManager.fileExists(atPath: crashReportsDir.path) {
            do {
                let crashFiles = try fileManager
                    .contentsOfDirectory(
                        at: crashReportsDir,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles]
                    )
                    .filter { url in
                        guard let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey]) else {
                            return false
                        }
                        return resourceValues.isRegularFile ?? false
                    }

                if !crashFiles.isEmpty {
                    Logger.shared.info("找到 \(crashFiles.count) 个崩溃报告文件")
                    return crashFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
                }
            } catch {
                Logger.shared.warning("读取崩溃报告文件夹失败: \(error.localizedDescription)")
            }
        }

        // 2. 如果没有崩溃报告，收集 logs/latest.log
        let logsDir = gameDirectory.appendingPathComponent("logs", isDirectory: true)
        let latestLog = logsDir.appendingPathComponent("latest.log")

        if fileManager.fileExists(atPath: latestLog.path) {
            Logger.shared.info("找到 latest.log 文件")
            return [latestLog]
        }

        Logger.shared.warning("未找到崩溃报告和 latest.log 文件")
        return []
    }

    /// 打开 AI 窗口并发送日志
    /// - Parameters:
    ///   - logFiles: 日志文件 URL 数组
    ///   - gameName: 游戏名称
    private func openAIWindowWithLogs(logFiles: [URL], gameName: String) async {
        // 创建 ChatState
        let chatState = ChatState()

        // 准备附件
        var attachments: [MessageAttachmentType] = []
        for logFile in logFiles {
            attachments.append(.file(logFile, logFile.lastPathComponent))
        }

        // 打开窗口
        TemporaryWindowManager.shared.showWindow(
            content: AIChatWindowView(chatState: chatState),
            config: .aiChat(title: "ai.assistant.title".localized())
        )

        // 等待窗口打开后发送消息
        try? await Task.sleep(nanoseconds: 100_000_000) // 等待 0.1 秒

        // 发送消息和附件
        await AIChatManager.shared.sendMessage("", attachments: attachments, chatState: chatState)
    }
}
