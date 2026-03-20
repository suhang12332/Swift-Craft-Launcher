import SwiftUI
import AppKit

/// SwiftUI 包装的文件树（内部使用 NSOutlineView；NSOutlineView 是 NSTableView 的子类）
public struct FileTreeView: NSViewRepresentable {
    public typealias NSViewType = NSScrollView

    private let rootURL: URL
    private let showHiddenFiles: Bool
    private let onSelectionChange: (([URL]) -> Void)?

    public init(
        rootURL: URL,
        showHiddenFiles: Bool = false,
        onSelectionChange: (([URL]) -> Void)? = nil
    ) {
        self.rootURL = rootURL
        self.showHiddenFiles = showHiddenFiles
        self.onSelectionChange = onSelectionChange
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(rootURL: rootURL, showHiddenFiles: showHiddenFiles, onSelectionChange: onSelectionChange)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.rowSizeStyle = .medium
        outlineView.usesAlternatingRowBackgroundColors = true
        outlineView.autosaveExpandedItems = false
        outlineView.allowsMultipleSelection = false
        outlineView.allowsEmptySelection = true
        outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        outlineView.focusRingType = .none

        let nameColumn = NSTableColumn(identifier: .nameColumn)
        nameColumn.title = NSLocalizedString("Name", comment: "File tree name column title")
        nameColumn.resizingMask = NSTableColumn.ResizingOptions.autoresizingMask
        outlineView.addTableColumn(nameColumn)
        outlineView.outlineTableColumn = nameColumn

        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.documentView = outlineView

        context.coordinator.outlineView = outlineView
        context.coordinator.reload()
        outlineView.expandItem(nil, expandChildren: false)

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let outlineView = nsView.documentView as? NSOutlineView else { return }
        context.coordinator.outlineView = outlineView
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.update(rootURL: rootURL, showHiddenFiles: showHiddenFiles)
    }
}
