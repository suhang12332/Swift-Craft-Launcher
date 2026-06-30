//
//  ModsDirectoryTreeWatcher.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CoreServices
import Foundation

/// Watches an entire directory tree for changes using FSEvents, including subdirectories.
final class ModsDirectoryTreeWatcher {
    private var stream: FSEventStreamRef?
    private let rootPath: String
    private let callback: () -> Void

    init(path: String, callback: @escaping () -> Void) {
        rootPath = (path as NSString).standardizingPath
        self.callback = callback

        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil,
        )

        let pathsToWatch = [path] as CFArray

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, numEvents, eventPathsPointer, _, _ in
                guard let info else { return }
                let watcher = Unmanaged<ModsDirectoryTreeWatcher>
                    .fromOpaque(info)
                    .takeUnretainedValue()
                let paths = eventPathsPointer.assumingMemoryBound(
                    to: UnsafePointer<CChar>?.self,
                )
                var changedPaths: [String] = []
                changedPaths.reserveCapacity(Int(numEvents))
                for i in 0 ..< Int(numEvents) {
                    if let cPath = paths[i] {
                        changedPaths.append(String(cString: cPath))
                    }
                }
                watcher.handleEvents(changedPaths: changedPaths)
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // Coalesces multiple change events within a short time window
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents),
        )

        if let stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    /// Responds only to direct child file events under the root directory, ignoring deeper changes.
    private func handleEvents(changedPaths: [String]) {
        let standardizedRoot = rootPath
        let prefix = standardizedRoot.hasSuffix("/") ? standardizedRoot : standardizedRoot + "/"

        let hasDirectChildChange = changedPaths.contains { fullPath in
            let standardized = (fullPath as NSString).standardizingPath
            guard standardized.hasPrefix(prefix) else { return false }
            let relative = String(standardized.dropFirst(prefix.count))
            return !relative.isEmpty && !relative.contains("/")
        }

        if hasDirectChildChange {
            callback()
        }
    }

    deinit {
        guard let stream else { return }
        let teardown = {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        if Thread.isMainThread {
            teardown()
        } else {
            DispatchQueue.main.sync(execute: teardown)
        }
    }
}
