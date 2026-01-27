import SwiftUI
import AppKit

// MARK: - 日志信息区域视图
struct LogSectionView: View {
    // MARK: - Properties
    let logs: [LogInfo]
    let isLoading: Bool

    // MARK: - Body
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
    
    // MARK: - Chip Builder
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

    // MARK: - Actions
    /// 使用Console应用打开日志文件
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

