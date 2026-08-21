//
//  InstallationDiagnosticsLogger.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Writes a durable, per-attempt installation trace without affecting the installation itself.
final class InstallationDiagnosticsLogger: @unchecked Sendable {
    static let shared = InstallationDiagnosticsLogger(directory: AppPaths.diagnosticsDirectory)

    private let directory: URL
    private let lock = NSLock()
    private var logURLs: [UUID: URL] = [:]
    private let dateFormatter: ISO8601DateFormatter

    init(directory: URL) {
        self.directory = directory
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    @discardableResult
    func begin(gameName: String, version: String, modLoader: String) -> UUID {
        let id = UUID()
        let timestamp = filenameTimestamp()
        let name = sanitize(timestamp + "-" + gameName + "-" + version + "-" + modLoader)
        let url = directory.appendingPathComponent("installation-" + name + "-" + id.uuidString + ".log")

        lock.lock()
        defer { lock.unlock() }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data().write(to: url, options: .atomic)
            logURLs[id] = url
            appendLocked(id: id, stage: "installation.begin", message: "gameName=\(gameName) version=\(version) modLoader=\(modLoader)")
        } catch {
            AppLog.game.error("Unable to create installation diagnostics: \(error.localizedDescription)")
        }
        return id
    }

    func record(_ id: UUID, stage: String, message: String) {
        lock.lock()
        defer { lock.unlock() }
        appendLocked(id: id, stage: stage, message: message)
    }

    func finish(_ id: UUID, success: Bool) {
        lock.lock()
        defer { lock.unlock() }
        appendLocked(id: id, stage: "installation.finish", message: "success=\(success)")
        logURLs[id] = nil
    }

    private func appendLocked(id: UUID, stage: String, message: String) {
        guard let url = logURLs[id] else { return }
        let line = "[\(dateFormatter.string(from: Date()))] [\(stage)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        do {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            AppLog.game.error("Unable to write installation diagnostics: \(error.localizedDescription)")
        }
    }

    private func filenameTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
    }
}
