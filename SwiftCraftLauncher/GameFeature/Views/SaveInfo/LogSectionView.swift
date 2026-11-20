//
//  LogSectionView.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import AppKit

// Displays log files as selectable chips with crash log highlighting.
import SwiftUI

struct LogSectionView: View {
    let logs: [LogInfo]
    let isLoading: Bool

    var body: some View {
        GenericSectionView(
            title: GameOverviewItem.Kind.log.titleKey,
            items: logs,
            isLoading: isLoading,
            iconName: GameOverviewItem.Kind.log.systemImage,
        ) { log in
            logChip(for: log)
        }
    }

    private func logChip(for log: LogInfo) -> some View {
        FilterChip(
            title: log.name,
            action: {
                openInConsole(log.path)
            },
            iconName: log.isCrashLog ? GameOverviewItem.errorSystemImage : GameOverviewItem.Kind.log.systemImage,
            customBackgroundColor: log.isCrashLog ? Color.red.opacity(0.1) : nil,
            customBorderColor: log.isCrashLog ? Color.red.opacity(0.3) : nil,
            maxTextWidth: 150,
            iconColor: log.isCrashLog ? .red : nil,
        )
    }

    private func openInConsole(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Console", url.path]

        do {
            try process.run()
        } catch {
            AppLog.game.error("Failed to open log file: \(error.localizedDescription)")
        }
    }
}
