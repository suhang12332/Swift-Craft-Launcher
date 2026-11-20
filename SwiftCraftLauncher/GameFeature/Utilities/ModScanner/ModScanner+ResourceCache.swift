//
//  ModScanner+ResourceCache.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModScanner {
    /// Caches archive directory listings and refreshes them when the directory changes.
    ///
    /// Both the Game Overview counts and the local resource list use this cache, so
    /// opening a game performs a single directory scan per resource type instead of
    /// scanning each directory independently.
    final class ResourceFileCache: @unchecked Sendable {
        private struct Entry {
            let modificationDate: Date
            let files: [URL]
        }

        private let condition = NSCondition()
        private let maximumEntries: Int
        private var entries: [String: Entry] = [:]
        private var inFlight: Set<String> = []
        private var cacheGeneration = 0

        init(maximumEntries: Int = 64) {
            self.maximumEntries = max(maximumEntries, 1)
        }

        private static func cacheKey(for directory: URL) -> String {
            directory.standardizedFileURL.resolvingSymlinksInPath().path
        }

        /// Returns the jar, zip, and disabled archive files in `directory`.
        ///
        /// The directory is re-read only when its modification date changes.
        /// Returns an empty array when the directory does not exist.
        func archiveFiles(in directory: URL) throws -> [URL] {
            try archiveFiles(in: directory, missingDirectoryIsError: false)
        }

        /// Returns the archive files in `directory`, throwing when the directory does not exist.
        func existingArchiveFiles(in directory: URL) throws -> [URL] {
            try archiveFiles(in: directory, missingDirectoryIsError: true)
        }

        /// Removes the cached listing for a directory.
        func invalidate(_ directory: URL) {
            let key = Self.cacheKey(for: directory)
            condition.lock()
            defer { condition.unlock() }
            entries.removeValue(forKey: key)
            cacheGeneration &+= 1
        }

        private func archiveFiles(
            in directory: URL,
            missingDirectoryIsError: Bool,
        ) throws -> [URL] {
            let standardizedDirectory = directory.standardizedFileURL.resolvingSymlinksInPath()
            let key = Self.cacheKey(for: standardizedDirectory)

            condition.lock()
            while inFlight.contains(key) {
                condition.wait()
            }

            let attributes: [FileAttributeKey: Any]
            do {
                attributes = try FileManager.default.attributesOfItem(atPath: key)
            } catch {
                if Self.isMissing(error) {
                    entries.removeValue(forKey: key)
                    condition.unlock()
                    if missingDirectoryIsError {
                        throw Self.directoryNotFound(key)
                    }
                    return []
                }
                condition.unlock()
                throw Self.directoryReadFailed(key, error: error)
            }

            let modificationDate = attributes[.modificationDate] as? Date
            if let modificationDate,
               let cached = entries[key],
               cached.modificationDate == modificationDate {
                condition.unlock()
                return cached.files
            }

            inFlight.insert(key)
            let scanGeneration = cacheGeneration
            condition.unlock()

            let files: [URL]
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: standardizedDirectory,
                    includingPropertiesForKeys: nil,
                )
                files = contents.filter {
                    ModScanner.archiveExtensions.contains($0.pathExtension.lowercased())
                }
            } catch {
                condition.lock()
                if Self.isMissing(error) {
                    entries.removeValue(forKey: key)
                }
                inFlight.remove(key)
                condition.broadcast()
                condition.unlock()

                if Self.isMissing(error) {
                    if missingDirectoryIsError {
                        throw Self.directoryNotFound(key)
                    }
                    return []
                }
                throw Self.directoryReadFailed(key, error: error)
            }

            condition.lock()
            if scanGeneration == cacheGeneration, let modificationDate {
                entries[key] = Entry(modificationDate: modificationDate, files: files)
                trimIfNeeded()
            }
            inFlight.remove(key)
            condition.broadcast()
            condition.unlock()
            return files
        }

        private func trimIfNeeded() {
            guard entries.count > maximumEntries else { return }
            entries.removeAll(keepingCapacity: true)
        }

        private static func isMissing(_ error: Error) -> Bool {
            let nsError = error as NSError
            return nsError.domain == NSCocoaErrorDomain
                && nsError.code == CocoaError.Code.fileReadNoSuchFile.rawValue
        }

        private static func directoryNotFound(_ key: String) -> GlobalError {
            GlobalError.resource(
                i18nKey: "error.resource.directory_not_found",
                level: .silent,
                message: "directory not found: \(key)",
            )
        }

        private static func directoryReadFailed(_ key: String, error: Error) -> GlobalError {
            GlobalError.fileSystem(
                i18nKey: "error.filesystem.directory_read_failed",
                level: .silent,
                message: "failed to read directory: \(key), error: \(error.localizedDescription)",
            )
        }
    }
}
