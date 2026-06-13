import Foundation
import SwiftUI
import Combine

/// 游戏图标缓存管理器
/// 图标缓存，避免重复文件系统访问
/// 使用 @unchecked Sendable 因为已经通过 DispatchQueue 确保线程安全
final class GameIconCache: @unchecked Sendable {
    static let shared = GameIconCache()

    /// 图标文件存在性缓存：key 为 "gameName/iconName"，value 为是否存在
    private let existenceCache = NSCache<NSString, NSNumber>()

    /// 图标 URL 缓存：key 为 "gameName/iconName"，value 为图标 URL
    private let urlCache = NSCache<NSString, NSURL>()

    /// 缓存访问队列，确保线程安全
    private let cacheQueue = DispatchQueue(label: "com.swiftcraftlauncher.gameiconcache", attributes: .concurrent)

    /// 缓存失效通知：当缓存被清除时发送通知
    /// key 为游戏名称，nil 表示清除所有缓存
    private let cacheInvalidationSubject = PassthroughSubject<String?, Never>()

    /// 缓存失效通知的发布者
    var cacheInvalidationPublisher: AnyPublisher<String?, Never> {
        cacheInvalidationSubject.eraseToAnyPublisher()
    }

    private init() {
        // 设置缓存限制
        existenceCache.countLimit = 100
        urlCache.countLimit = 100
    }

    /// 获取游戏图标的 URL
    /// - Parameters:
    ///   - gameName: 游戏名称
    ///   - iconName: 图标文件名
    /// - Returns: 图标的 URL
    func iconURL(gameName: String, iconName: String) -> URL {
        let cacheKey = "\(gameName)/\(iconName)" as NSString

        return cacheQueue.sync {
            if let cachedURL = urlCache.object(forKey: cacheKey) {
                return cachedURL as URL
            }

            let profileDir = AppPaths.profileDirectory(gameName: gameName)
            let iconURL = profileDir.appendingPathComponent(iconName)
            urlCache.setObject(iconURL as NSURL, forKey: cacheKey)
            return iconURL
        }
    }

    /// 检查图标文件是否存在（带缓存）
    /// - Parameters:
    ///   - gameName: 游戏名称
    ///   - iconName: 图标文件名
    /// - Returns: 图标文件是否存在
    func iconExists(gameName: String, iconName: String) -> Bool {
        let cacheKey = "\(gameName)/\(iconName)" as NSString

        return cacheQueue.sync {
            if let cached = existenceCache.object(forKey: cacheKey) {
                return cached.boolValue
            }

            let iconURL = self.iconURL(gameName: gameName, iconName: iconName)
            let exists = FileManager.default.fileExists(atPath: iconURL.path)
            existenceCache.setObject(NSNumber(value: exists), forKey: cacheKey)
            return exists
        }
    }

    /// 异步检查图标文件是否存在（在后台线程执行）
    /// - Parameters:
    ///   - gameName: 游戏名称
    ///   - iconName: 图标文件名
    /// - Returns: 图标文件是否存在
    func iconExistsAsync(gameName: String, iconName: String) async -> Bool {
        let cacheKeyString = "\(gameName)/\(iconName)"

        let cacheKey = cacheKeyString as NSString
        let cached = cacheQueue.sync {
            existenceCache.object(forKey: cacheKey)
        }

        if let cached = cached {
            return cached.boolValue
        }

        // 在后台线程检查文件存在性
        let exists = await Task.detached(priority: .utility) {
            // 在后台线程获取 URL（不依赖 self）
            let profileDir = AppPaths.profileDirectory(gameName: gameName)
            let iconURL = profileDir.appendingPathComponent(iconName)
            return FileManager.default.fileExists(atPath: iconURL.path)
        }.value

        let existsValue = exists
        cacheQueue.async(flags: .barrier) {
            let cacheKey = cacheKeyString as NSString
            self.existenceCache.setObject(NSNumber(value: existsValue), forKey: cacheKey)
        }

        return exists
    }

    /// 清除特定游戏的图标缓存
    /// - Parameter gameName: 游戏名称
    func invalidateCache(for gameName: String) {
        cacheQueue.async(flags: .barrier) {
            self.existenceCache.removeAllObjects()
            self.urlCache.removeAllObjects()

            // 发送缓存失效通知
            DispatchQueue.main.async {
                self.cacheInvalidationSubject.send(gameName)
            }
        }
    }

    /// 清除所有缓存
    func clearAllCache() {
        cacheQueue.async(flags: .barrier) {
            self.existenceCache.removeAllObjects()
            self.urlCache.removeAllObjects()

            DispatchQueue.main.async {
                self.cacheInvalidationSubject.send(nil)
            }
        }
    }
}
