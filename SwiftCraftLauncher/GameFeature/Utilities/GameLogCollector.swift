//
//  GameLogCollector.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Collects game crash logs and presents them in an AI chat window.
@MainActor
class GameLogCollector {
    static let shared = GameLogCollector()
    private let errorHandler: GlobalErrorHandler
    private let windowManager: WindowManager
    private let aiChatManager: AIChatManager
    private let windowDataStore: WindowDataStore

    private init(
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
        windowManager: WindowManager = AppServices.windowManager,
        aiChatManager: AIChatManager = AppServices.aiChatManager,
        windowDataStore: WindowDataStore = AppServices.windowDataStore,
    ) {
        self.errorHandler = errorHandler
        self.windowManager = windowManager
        self.aiChatManager = aiChatManager
        self.windowDataStore = windowDataStore
    }

    /// Collects log files for the specified game and opens the AI chat window.
    /// - Parameter gameName: The name of the game instance.
    func collectAndOpenAIWindow(gameName: String) async {
        let logFiles = await collectLogFiles(gameName: gameName)

        if logFiles.isEmpty {
            let error = GlobalError.fileSystem(
                chineseMessage: "未找到游戏日志文件",
                i18nKey: "error.filesystem.logs_not_found",
                level: .notification,
            )
            errorHandler.handle(error)
            return
        }

        await openAIWindowWithLogs(logFiles: logFiles, gameName: gameName)
    }

    /// Collects available log files from the game's profile directory.
    /// - Parameter gameName: The name of the game instance.
    /// - Returns: An array of log file URLs, prioritizing crash reports over latest.log.
    private func collectLogFiles(gameName: String) async -> [URL] {
        let gameDirectory = AppPaths.profileDirectory(gameName: gameName)
        let fileManager = FileManager.default

        let crashReportsDir = gameDirectory.appendingPathComponent(AppConstants.DirectoryNames.crashReports, isDirectory: true)

        if fileManager.fileExists(atPath: crashReportsDir.path) {
            do {
                let crashFiles = try fileManager
                    .contentsOfDirectory(
                        at: crashReportsDir,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles],
                    )
                    .filter { url in
                        guard let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey]) else {
                            return false
                        }
                        return resourceValues.isRegularFile ?? false
                    }

                if !crashFiles.isEmpty {
                    AppLog.game.info("找到 \(crashFiles.count) 个崩溃报告文件")
                    return crashFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
                }
            } catch {
                AppLog.game.error("读取崩溃报告文件夹失败: \(error.localizedDescription)")
            }
        }

        let logsDir = gameDirectory.appendingPathComponent("logs", isDirectory: true)
        let latestLog = logsDir.appendingPathComponent("latest.log")

        if fileManager.fileExists(atPath: latestLog.path) {
            AppLog.game.info("找到 latest.log 文件")
            return [latestLog]
        }

        AppLog.game.error("未找到崩溃报告和 latest.log 文件")
        return []
    }

    /// Opens the AI chat window and sends log file attachments.
    /// - Parameters:
    ///   - logFiles: The log file URLs to attach.
    ///   - gameName: The name of the game instance.
    private func openAIWindowWithLogs(logFiles: [URL], gameName _: String) async {
        let chatState = ChatState()

        var attachments: [MessageAttachmentType] = []
        for logFile in logFiles {
            attachments.append(.file(logFile, logFile.lastPathComponent))
        }

        windowDataStore.aiChatState = chatState
        windowManager.openWindow(id: .aiChat)

        try? await Task.sleep(nanoseconds: 100_000_000)

        await aiChatManager.sendMessage("", attachments: attachments, chatState: chatState)
    }
}
