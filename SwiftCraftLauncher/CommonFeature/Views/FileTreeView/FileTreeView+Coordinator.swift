import SwiftUI
import AppKit

// MARK: - Coordinator

extension FileTreeView {
    public final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        private let viewModel: FileTreeViewModel

        weak var outlineView: NSOutlineView?
        var onSelectionChange: (([URL]) -> Void)?

        private let iconProvider = NSWorkspace.shared

        init(rootURL: URL, showHiddenFiles: Bool, onSelectionChange: (([URL]) -> Void)?) {
            self.viewModel = FileTreeViewModel(rootURL: rootURL, showHiddenFiles: showHiddenFiles)
            self.onSelectionChange = onSelectionChange
            super.init()
        }

        func update(rootURL: URL, showHiddenFiles: Bool) {
            let didChangeHidden = (showHiddenFiles != viewModel.showHiddenFiles)
            let didChangeRoot = viewModel.update(rootURL: rootURL, showHiddenFiles: showHiddenFiles)

            guard didChangeRoot || didChangeHidden else { return }

            reload()
            if didChangeRoot {
                onSelectionChange?([])
            }
        }

        func reload() {
            viewModel.reload()
            outlineView?.reloadData()
        }

        // MARK: NSOutlineViewDataSource

        public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            let node = (item as? FileNode) ?? viewModel.root
            viewModel.ensureChildrenLoaded(for: node)
            return node.children?.count ?? 0
        }

        public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            let node = (item as? FileNode) ?? viewModel.root
            viewModel.ensureChildrenLoaded(for: node)
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

        // MARK: - Selection

        @objc private func toggleSelection(_ sender: NSButton) {
            guard
                let outlineView,
                outlineView.row(for: sender) >= 0,
                let node = outlineView.item(atRow: outlineView.row(for: sender)) as? FileNode
            else { return }

            let refreshNodes = viewModel.toggleSelection(for: node)

            // 局部刷新：当前节点刷新子树；祖先只刷新自身
            outlineView.reloadItem(node, reloadChildren: true)
            for parent in refreshNodes.dropFirst() {
                outlineView.reloadItem(parent, reloadChildren: false)
            }

            onSelectionChange?(viewModel.selectedFileURLs())
        }
    }
}

