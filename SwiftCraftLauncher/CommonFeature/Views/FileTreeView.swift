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

// MARK: - Coordinator

extension FileTreeView {
    public final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        private var root: FileNode
        private var showHiddenFiles: Bool
        weak var outlineView: NSOutlineView?
        var onSelectionChange: (([URL]) -> Void)?

        private let fm = FileManager.default
        private let iconProvider = NSWorkspace.shared

        init(rootURL: URL, showHiddenFiles: Bool, onSelectionChange: (([URL]) -> Void)?) {
            self.root = FileNode(url: rootURL)
            self.showHiddenFiles = showHiddenFiles
            self.onSelectionChange = onSelectionChange
            super.init()
        }

        func update(rootURL: URL, showHiddenFiles: Bool) {
            let needsRootReload = root.url != rootURL
            let needsHiddenReload = self.showHiddenFiles != showHiddenFiles
            self.showHiddenFiles = showHiddenFiles

            if needsRootReload {
                root = FileNode(url: rootURL)
                // 根目录变更时，重载并清空外部选中列表
                reload()
                onSelectionChange?([])
            } else if needsHiddenReload {
                // 仅隐藏文件显示开关变化时，保持外部选中列表不变
                reload()
            }
        }

        func reload() {
            root.resetChildren()
            outlineView?.reloadData()
        }

        // MARK: NSOutlineViewDataSource

        public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            let node = (item as? FileNode) ?? root
            ensureChildrenLoaded(for: node)
            return node.children?.count ?? 0
        }

        public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            let node = (item as? FileNode) ?? root
            ensureChildrenLoaded(for: node)
            guard let children = node.children, index < children.count else {
                return node
            }
            return children[index]
        }

        public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            guard let node = item as? FileNode else { return false }
            return node.isDirectory
        }

        // MARK: NSOutlineViewDelegate

        public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let node = item as? FileNode else { return nil }

            let identifier = NSUserInterfaceItemIdentifier.cell
            let cell: FileTreeCellView
            if let reused = outlineView.makeView(withIdentifier: identifier, owner: nil) as? FileTreeCellView {
                cell = reused
            } else {
                cell = FileTreeCellView(toggleTarget: self, toggleAction: #selector(toggleSelection(_:)))
                cell.identifier = identifier
            }

            cell.titleField.stringValue = node.displayName
            cell.iconView.image = iconProvider.icon(forFile: node.url.path)
            cell.iconView.image?.size = NSSize(width: 16, height: 16)
            cell.checkbox.state = node.selection.controlState

            return cell
        }

        public func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
            true
        }

        // MARK: - Loading

        private func ensureChildrenLoaded(for node: FileNode) {
            guard node.children == nil else { return }
            guard node.isDirectory else {
                node.children = []
                return
            }

            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: node.url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                node.children = []
                return
            }

            let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .localizedNameKey]
            let options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]

            do {
                let urls = try fm.contentsOfDirectory(
                    at: node.url,
                    includingPropertiesForKeys: keys,
                    options: options
                )

                node.children = urls
                    .filter { url in
                        guard showHiddenFiles == false else { return true }
                        return (try? url.resourceValues(forKeys: [.isHiddenKey]).isHidden) != true
                    }
                    .map { url -> FileNode in
                        let child = FileNode(url: url)
                        child.parent = node
                        return child
                    }
                    .sorted { lhs, rhs in
                        if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
                        return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                    }
            } catch {
                node.children = []
            }
        }

        // MARK: - Selection

        @objc private func toggleSelection(_ sender: NSButton) {
            guard
                let outlineView,
                outlineView.row(for: sender) >= 0,
                let node = outlineView.item(atRow: outlineView.row(for: sender)) as? FileNode
            else { return }

            let targetIsOn: Bool
            if node.isDirectory {
                // 文件夹：当前为 all -> 变为 none；否则都视为全选
                targetIsOn = node.selection != .all
            } else {
                // 文件：简单开关
                targetIsOn = node.selection != .all
            }

            applySelection(to: node, isOn: targetIsOn)

            // 局部刷新：只刷新当前节点及其祖先节点，避免整棵树 reload，减少开销
            outlineView.reloadItem(node, reloadChildren: true)
            var parent = node.parent
            while let current = parent {
                outlineView.reloadItem(current, reloadChildren: false)
                parent = current.parent
            }

            onSelectionChange?(selectedFileURLs())
        }

        /// 应用选择状态并向下/向上传播，用于保证父、子节点的三态一致
        private func applySelection(to node: FileNode, isOn: Bool) {
            let newState: SelectionState = isOn ? .all : .unselected
            node.selection = newState

            // 向下：更新所有已加载子节点
            if node.isDirectory {
                ensureChildrenLoaded(for: node)
                node.children?.forEach { child in
                    applySelectionDown(child, state: newState)
                }
            }

            // 向上：从当前节点开始逐级汇总子节点状态
            updateParentsSelection(from: node)
        }

        private func applySelectionDown(_ node: FileNode, state: SelectionState) {
            node.selection = state
            guard node.isDirectory else { return }
            ensureChildrenLoaded(for: node)
            node.children?.forEach { child in
                applySelectionDown(child, state: state)
            }
        }

        private func updateParentsSelection(from node: FileNode) {
            var currentParent = node.parent
            while let parent = currentParent {
                ensureChildrenLoaded(for: parent)
                let childrenStates = parent.children?.map(\.selection) ?? []

                if childrenStates.allSatisfy({ $0 == .all }) {
                    parent.selection = .all
                } else if childrenStates.allSatisfy({ $0 == .unselected }) {
                    parent.selection = .unselected
                } else {
                    parent.selection = .some
                }

                currentParent = parent.parent
            }
        }

        // MARK: - Export selected files

        private func selectedFileURLs() -> [URL] {
            var result: [URL] = []
            collectSelectedFiles(from: root, into: &result)
            return result
        }

        private func collectSelectedFiles(from node: FileNode, into result: inout [URL]) {
            if node.isDirectory {
                guard let children = node.children else { return }
                for child in children {
                    collectSelectedFiles(from: child, into: &result)
                }
                return
            }

            if node.selection == .all {
                result.append(node.url)
            }
        }
    }
}

// MARK: - Model

final class FileNode: NSObject {
    let url: URL
    let isDirectory: Bool
    let displayName: String

    weak var parent: FileNode?
    var selection: SelectionState = .unselected
    var children: [FileNode]?

    init(url: URL) {
        self.url = url

        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .localizedNameKey])
        self.isDirectory = values?.isDirectory ?? false
        self.displayName = values?.localizedName ?? url.lastPathComponent

        super.init()
    }

    func resetChildren() {
        children = nil
    }
}

// MARK: - Identifiers / Helpers

private extension NSUserInterfaceItemIdentifier {
    static let cell = NSUserInterfaceItemIdentifier("FileTreeCell")
    static let nameColumn = NSUserInterfaceItemIdentifier("name")
}

// MARK: - Selection State

enum SelectionState {
    case unselected
    case some
    case all

    var controlState: NSControl.StateValue {
        switch self {
        case .unselected:
            return .off
        case .all:
            return .on
        case .some:
            return .mixed
        }
    }
}

// MARK: - Cell

private final class FileTreeCellView: NSTableCellView {
    let checkbox: NSButton
    let iconView: NSImageView
    let titleField: NSTextField

    init(toggleTarget: AnyObject?, toggleAction: Selector) {
        self.checkbox = NSButton(checkboxWithTitle: "", target: toggleTarget, action: toggleAction)
        self.iconView = NSImageView()
        self.titleField = NSTextField(labelWithString: "")
        super.init(frame: .zero)

        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.setButtonType(.switch)
        checkbox.allowsMixedState = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        iconView.symbolConfiguration = .init(pointSize: 14, weight: .regular)

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.lineBreakMode = .byTruncatingMiddle

        imageView = iconView
        textField = titleField

        let stack = NSStackView(views: [checkbox, iconView, titleField])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.distribution = .fill
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 6)
        addSubview(stack)

        NSLayoutConstraint.activate([
            checkbox.widthAnchor.constraint(equalToConstant: 18),
            checkbox.heightAnchor.constraint(equalToConstant: 18),

            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension NSView {
    func enclosingView<T: NSView>(of type: T.Type) -> T? {
        var view: NSView? = self
        while let current = view {
            if let target = current as? T {
                return target
            }
            view = current.superview
        }
        return nil
    }
}
