//
//  AppCacheManager.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides thread-safe JSON-based caching organized by namespaces.
class AppCacheManager {
    private let queue = DispatchQueue(label: "com.swiftcraftlauncher.appcachemanager")

    init() { }

    private func fileURL(for namespace: String) throws -> URL {
        do {
            try FileManager.default.createDirectory(at: AppPaths.appCache, withIntermediateDirectories: true)
        } catch {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.cache_directory_creation_failed",
                level: .notification,
                message: "Failed to create cache directory at \(AppPaths.appCache.path): \(error.localizedDescription)",
            )
        }

        return AppPaths.appCache.appendingPathComponent("\(namespace).json")
    }

    /// Stores a codable value in the specified namespace.
    /// - Parameters:
    ///   - namespace: The cache namespace.
    ///   - key: The cache key.
    ///   - value: The value to store.
    /// - Throws: A `GlobalError` when encoding or persistence fails.
    func set(namespace: String, key: String, value: some Codable) throws {
        try queue.sync {
            var nsDict = try loadNamespace(namespace)

            do {
                let data = try JSONEncoder().encode(value)
                nsDict[key] = data
                try saveNamespace(namespace, dict: nsDict)
            } catch {
                throw GlobalError.validation(
                    i18nKey: "error.validation.cache_data_encode_failed",
                    level: .notification,
                    message: "Failed to encode cache data for namespace \(namespace), key \(key): \(error.localizedDescription)",
                )
            }
        }
    }

    /// Stores a codable value silently, reporting errors to the error handler instead of throwing.
    /// - Parameters:
    ///   - namespace: The cache namespace.
    ///   - key: The cache key.
    ///   - value: The value to store.
    func setSilently(namespace: String, key: String, value: some Codable) {
        do {
            try set(namespace: namespace, key: key, value: value)
        } catch {
            DIContainer.shared.core.errorHandler.handle(error)
        }
    }

    /// Retrieves a cached value for the given key and namespace.
    /// - Parameters:
    ///   - namespace: The cache namespace.
    ///   - key: The cache key.
    ///   - type: The expected value type.
    /// - Returns: The decoded value, or `nil` if not found or decoding fails.
    func get<T: Codable>(namespace: String, key: String, as _: T.Type) -> T? {
        queue.sync {
            do {
                let nsDict = try loadNamespace(namespace)
                guard let data = nsDict[key] else { return nil }

                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    DIContainer.shared.core.errorHandler.handle(GlobalError.validation(
                        i18nKey: "error.validation.cache_data_decode_failed",
                        level: .silent,
                        message: "Failed to decode cache data for namespace \(namespace), key \(key): \(error.localizedDescription)",
                    ))
                    return nil
                }
            } catch {
                DIContainer.shared.core.errorHandler.handle(error)
                return nil
            }
        }
    }

    private func loadNamespace(_ namespace: String) throws -> [String: Data] {
        let url = try fileURL(for: namespace)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: Data].self, from: data)
        } catch {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.cache_read_failed",
                level: .notification,
                message: "Failed to read cache file for namespace \(namespace) from \(url.path): \(error.localizedDescription)",
            )
        }
    }

    private func saveNamespace(_ namespace: String, dict: [String: Data]) throws {
        let url = try fileURL(for: namespace)

        do {
            let data = try JSONEncoder().encode(dict)
            try data.write(to: url)
        } catch {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.cache_write_failed",
                level: .notification,
                message: "Failed to write cache file for namespace \(namespace) to \(url.path): \(error.localizedDescription)",
            )
        }
    }
}
