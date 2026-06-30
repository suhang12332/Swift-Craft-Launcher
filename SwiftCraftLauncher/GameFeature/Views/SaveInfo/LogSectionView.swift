//
//  LogSectionView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

/// Displays log files as selectable chips with crash log highlighting.
import SwiftUI
import AppKit

struct LogSectionView: View {
    let logs: [LogInfo]
    let isLoading: Bool

    var body: some View {
        GenericSectionView(
            title: "saveinfo.logs",
            items: logs,
            isLoading: isLoading,
            iconName: "doc.text.fill"
        ) { log in
            logChip(for: log)
        }
    }

    private func logChip(for log: LogInfo) -> some View {
        FilterChip(
            title: log.name,
            action: {
                openLogInConsole(log: log)
            },
            iconName: log.isCrashLog ? "exclamationmark.triangle.fill" : "doc.text.fill",
            isLoading: false,
            customBackgroundColor: log.isCrashLog ? Color.red.opacity(0.1) : nil,
            customBorderColor: log.isCrashLog ? Color.red.opacity(0.3) : nil,
            maxTextWidth: 150,
            iconColor: log.isCrashLog ? .red : nil
        )
    }

    private func openLogInConsole(log: LogInfo) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Console", log.path.path]

        do {
            try process.run()
        } catch {
            Logger.shared.error("打开日志文件失败: \(error.localizedDescription)")
        }
    }
}
