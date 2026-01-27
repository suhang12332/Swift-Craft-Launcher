import SwiftUI
import AppKit

// MARK: - Constants
private enum LogSectionConstants {
    static let maxHeight: CGFloat = 235
    static let verticalPadding: CGFloat = 4
    static let headerBottomPadding: CGFloat = 4
    static let placeholderCount: Int = 5
    static let popoverWidth: CGFloat = 320
    static let popoverMaxHeight: CGFloat = 320
    static let chipPadding: CGFloat = 16
    static let estimatedCharWidth: CGFloat = 10
    static let maxItems: Int = 6  // 最多显示6个
    static let maxWidth: CGFloat = 320
}

// MARK: - 日志信息区域视图
struct LogSectionView: View {
    // MARK: - Properties
    let logs: [LogInfo]
    let isLoading: Bool

    @State private var showOverflowPopover = false

    // MARK: - Body
    var body: some View {
        VStack {
            headerView
            if isLoading {
                loadingPlaceholder
            } else {
                contentWithOverflow
            }
        }
    }

    // MARK: - Header Views
    private var headerView: some View {
        let (_, overflowItems) = logs.computeVisibleAndOverflowItems(maxItems: LogSectionConstants.maxItems)
        return HStack {
            headerTitle
            Spacer()
            if !overflowItems.isEmpty {
                OverflowButton(
                    count: overflowItems.count,
                    isPresented: $showOverflowPopover
                ) {
                    OverflowPopoverContent(
                        items: overflowItems,
                        maxHeight: LogSectionConstants.popoverMaxHeight,
                        width: LogSectionConstants.popoverWidth
                    ) { log in
                        logChip(for: log)
                    }
                }
            }
        }
        .padding(.bottom, LogSectionConstants.headerBottomPadding)
    }

    private var headerTitle: some View {
        Text("saveinfo.logs".localized())
            .font(.headline)
    }

    // MARK: - Content Views
    private var loadingPlaceholder: some View {
        LoadingPlaceholder(
            count: LogSectionConstants.placeholderCount,
            iconName: "doc.text.fill",
            maxHeight: LogSectionConstants.maxHeight,
            verticalPadding: LogSectionConstants.verticalPadding
        )
    }

    private var contentWithOverflow: some View {
        let (visibleItems, _) = logs.computeVisibleAndOverflowItems(maxItems: LogSectionConstants.maxItems)
        return ContentWithOverflow(
            items: visibleItems,
            maxHeight: LogSectionConstants.maxHeight,
            verticalPadding: LogSectionConstants.verticalPadding
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

