import Foundation

/// 承载文件树的数据与业务逻辑（加载、三态选择、导出选中文件）。
///
/// 说明：
/// - NSOutlineView 的 dataSource/delegate 仍由 Coordinator 负责；本类只提供纯逻辑与可测试的状态。
final class FileTreeViewModel {
    private(set) var root: FileNode
    private(set) var showHiddenFiles: Bool

    private let fm: FileManager

    init(rootURL: URL, showHiddenFiles: Bool, fileManager: FileManager = .default) {
        self.root = FileNode(url: rootURL)
        self.showHiddenFiles = showHiddenFiles
        self.fm = fileManager
    }

    /// 更新输入参数并在需要时重建根节点。
    /// - Returns: 是否发生了根目录变更（便于调用方决定是否清空外部选中）。
    @discardableResult
    func update(rootURL: URL, showHiddenFiles: Bool) -> Bool {
        let needsRootReload = root.url != rootURL
        self.showHiddenFiles = showHiddenFiles
        if needsRootReload {
            root = FileNode(url: rootURL)
        }
        return needsRootReload
    }

    func reload() {
        root.resetChildren()
    }

    // MARK: - Loading

    func ensureChildrenLoaded(for node: FileNode) {
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

    /// 切换节点选择状态，并保证父、子三态一致。
    /// - Returns: 需要在 UI 上刷新的节点（self + 祖先）。
    func toggleSelection(for node: FileNode) -> [FileNode] {
        let targetIsOn: Bool
        if node.isDirectory {
            // 文件夹：当前为 all -> 变为 none；否则都视为全选
            targetIsOn = node.selection != .all
        } else {
            // 文件：简单开关
            targetIsOn = node.selection != .all
        }

        applySelection(to: node, isOn: targetIsOn)
        return node.selfAndAncestors()
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

    func selectedFileURLs() -> [URL] {
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
