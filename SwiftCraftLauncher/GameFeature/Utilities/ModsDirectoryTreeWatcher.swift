import Foundation
import CoreServices

/// 使用 FSEvents 监控整个目录树变化（包含子目录）
final class ModsDirectoryTreeWatcher {
    private var stream: FSEventStreamRef?
    private let rootPath: String
    private let callback: () -> Void

    init(path: String, callback: @escaping () -> Void) {
        self.rootPath = (path as NSString).standardizingPath
        self.callback = callback

        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch = [path] as CFArray

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, numEvents, eventPathsPointer, _, _ in
                guard let info = info else { return }
                let watcher = Unmanaged<ModsDirectoryTreeWatcher>
                    .fromOpaque(info)
                    .takeUnretainedValue()
                // 将 C 数组的路径转换为 [String]
                let paths = eventPathsPointer.assumingMemoryBound(
                    to: UnsafePointer<CChar>?.self
                )
                var changedPaths: [String] = []
                changedPaths.reserveCapacity(Int(numEvents))
                for i in 0..<Int(numEvents) {
                    if let cPath = paths[i] {
                        changedPaths.append(String(cString: cPath))
                    }
                }
                watcher.handleEvents(changedPaths: changedPaths)
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,  // 合并短时间内的多次变更事件
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        )

        if let stream = stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    /// 只对根目录下的直接子文件事件做响应，忽略子目录更深层级的变化
    private func handleEvents(changedPaths: [String]) {
        let standardizedRoot = rootPath
        let prefix = standardizedRoot.hasSuffix("/") ? standardizedRoot : standardizedRoot + "/"

        let hasDirectChildChange = changedPaths.contains { fullPath in
            let standardized = (fullPath as NSString).standardizingPath
            guard standardized.hasPrefix(prefix) else { return false }
            let relative = String(standardized.dropFirst(prefix.count))
            // 只接受形如 "file.jar" 的路径，过滤掉 "subdir/file.jar"
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
