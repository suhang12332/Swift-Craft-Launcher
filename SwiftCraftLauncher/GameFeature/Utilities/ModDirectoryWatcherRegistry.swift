import Foundation

actor ModDirectoryWatcherRegistry {
    static let shared = ModDirectoryWatcherRegistry()

    private var watchers: [String: ModsDirectoryTreeWatcher] = [:]

    private init() {}

    func ensureWatching(directoryURL: URL, gameNameHint: String?) {
        let standardized = directoryURL.standardizedFileURL
        let key = standardized.path
        if watchers[key] != nil {
            return
        }
        guard FileManager.default.fileExists(atPath: key) else {
            return
        }

        let hint = gameNameHint
        let watcher = ModsDirectoryTreeWatcher(path: key) {
            ModScanner.shared.scheduleDirectoryHashRebuild(
                standardizedDirectoryURL: standardized,
                gameNameHint: hint
            )
        }
        watchers[key] = watcher
    }
}
