import Foundation

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

    func selfAndAncestors() -> [FileNode] {
        var result: [FileNode] = [self]
        var p = parent
        while let current = p {
            result.append(current)
            p = current.parent
        }
        return result
    }
}
