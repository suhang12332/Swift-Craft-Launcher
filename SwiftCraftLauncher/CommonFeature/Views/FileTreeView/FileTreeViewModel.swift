//
//  FileTreeViewModel.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages file tree data and selection logic.
///
/// The NSOutlineView data source and delegate are handled by the coordinator.
/// This class provides pure logic and testable state.
final class FileTreeViewModel {
    private(set) var root: FileNode
    private(set) var showHiddenFiles: Bool

    private let fm: FileManager
    private var didAttemptApplyDefaultSelection = false

    init(rootURL: URL, showHiddenFiles: Bool, fileManager: FileManager = .default) {
        root = FileNode(url: rootURL)
        self.showHiddenFiles = showHiddenFiles
        fm = fileManager
    }

    /// Updates the root URL and hidden files setting.
    ///
    /// - Returns: Whether the root directory changed.
    @discardableResult
    func update(rootURL: URL, showHiddenFiles: Bool) -> Bool {
        let needsRootReload = root.url != rootURL
        self.showHiddenFiles = showHiddenFiles
        if needsRootReload {
            root = FileNode(url: rootURL)
            didAttemptApplyDefaultSelection = false
        }
        return needsRootReload
    }

    func reload() {
        root.resetChildren()
    }

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
                options: options,
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

    /// Toggles the selection state of a node, maintaining tri-state consistency.
    ///
    /// - Returns: Nodes that need UI refresh (self and ancestors).
    func toggleSelection(for node: FileNode) -> [FileNode] {
        let targetIsOn: Bool
        if node.isDirectory {
            targetIsOn = node.selection != .all
        } else {
            targetIsOn = node.selection != .all
        }

        applySelection(to: node, isOn: targetIsOn)
        return node.selfAndAncestors()
    }

    private func applySelection(to node: FileNode, isOn: Bool) {
        let newState: SelectionState = isOn ? .all : .unselected
        node.selection = newState

        if node.isDirectory {
            ensureChildrenLoaded(for: node)
            node.children?.forEach { child in
                applySelectionDown(child, state: newState)
            }
        }

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

extension FileTreeViewModel {
    /// Applies default selection to common top-level files if not already done.
    ///
    /// - Returns: Whether the selection state changed.
    @discardableResult
    func applyDefaultSelectionIfNeeded() -> Bool {
        guard didAttemptApplyDefaultSelection == false else { return false }
        didAttemptApplyDefaultSelection = true
        ensureChildrenLoaded(for: root)
        guard let topLevelNodes = root.children, topLevelNodes.isEmpty == false else { return false }

        var didChange = false
        let defaultSet = Set(AppConstants.defaultFileTreeTopLevelSelections.map { $0.lowercased() })

        for node in topLevelNodes {
            let name = node.url.lastPathComponent.lowercased()
            guard defaultSet.contains(name) else { continue }
            guard node.selection != .all else { continue }

            applySelection(to: node, isOn: true)
            didChange = true
        }

        return didChange
    }
}
