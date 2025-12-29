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
        let (_, overflowItems) = computeVisibleAndOverflowItems()
        return HStack {
            headerTitle
            Spacer()
            if !overflowItems.isEmpty {
                overflowButton(overflowItems: overflowItems)
            }
        }
        .padding(.bottom, LogSectionConstants.headerBottomPadding)
    }
    
    private var headerTitle: some View {
        Text("saveinfo.logs".localized())
            .font(.headline)
    }
    
    private func overflowButton(overflowItems: [LogInfo]) -> some View {
        Button {
            showOverflowPopover = true
        } label: {
            Text("+\(overflowItems.count)")
                .font(.caption)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showOverflowPopover, arrowEdge: .leading) {
            overflowPopoverContent(overflowItems: overflowItems)
        }
    }
    
    private func overflowPopoverContent(
        overflowItems: [LogInfo]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                FlowLayout {
                    ForEach(overflowItems) { log in
                        LogChip(
                            title: log.name,
                            isCrashLog: log.isCrashLog,
                            isLoading: false
                        ) {
                            openLogInConsole(log: log)
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: LogSectionConstants.popoverMaxHeight)
        }
        .frame(width: LogSectionConstants.popoverWidth)
    }
    
    // MARK: - Content Views
    private var loadingPlaceholder: some View {
        ScrollView {
            FlowLayout {
                ForEach(
                    0..<LogSectionConstants.placeholderCount,
                    id: \.self
                ) { _ in
                    LogChip(
                        title: "common.loading".localized(),
                        isCrashLog: false,
                        isLoading: true
                    )
                    .redacted(reason: .placeholder)
                }
            }
        }
        .frame(maxHeight: LogSectionConstants.maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, LogSectionConstants.verticalPadding)
    }
    
    private var contentWithOverflow: some View {
        let (visibleItems, _) = computeVisibleAndOverflowItems()
        return FlowLayout {
            ForEach(visibleItems) { log in
                LogChip(
                    title: log.name,
                    isCrashLog: log.isCrashLog,
                    isLoading: false
                ) {
                    openLogInConsole(log: log)
                }
            }
        }
        .frame(maxHeight: LogSectionConstants.maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, LogSectionConstants.verticalPadding)
        .padding(.bottom, LogSectionConstants.verticalPadding)
    }
    
    // MARK: - Helper Methods
    private func computeVisibleAndOverflowItems() -> (
        [LogInfo], [LogInfo]
    ) {
        // 最多显示6个
        let visibleItems = Array(logs.prefix(LogSectionConstants.maxItems))
        let overflowItems = Array(logs.dropFirst(LogSectionConstants.maxItems))
        
        return (visibleItems, overflowItems)
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

// MARK: - Log Chip
struct LogChip: View {
    let title: String
    let isCrashLog: Bool
    let isLoading: Bool
    let action: (() -> Void)?
    
    init(title: String, isCrashLog: Bool, isLoading: Bool, action: (() -> Void)? = nil) {
        self.title = title
        self.isCrashLog = isCrashLog
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 4) {
                Image(systemName: isCrashLog ? "exclamationmark.triangle.fill" : "doc.text.fill")
                    .font(.caption)
                    .foregroundColor(isCrashLog ? .red : .primary)
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isCrashLog ? Color.red.opacity(0.1) : Color.clear)
            )
            .foregroundStyle(.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isCrashLog ? Color.red.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

