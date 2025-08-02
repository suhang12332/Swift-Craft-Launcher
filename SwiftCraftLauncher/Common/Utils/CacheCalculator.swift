import Foundation

// 缓存信息结构
struct CacheInfo {
    let fileCount: Int
    let totalSize: Int64 // 字节
    let formattedSize: String
    
    init(fileCount: Int, totalSize: Int64) {
        self.fileCount = fileCount
        self.totalSize = totalSize
        self.formattedSize = Self.formatFileSize(totalSize)
    }
    
    static func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// 缓存计算器
class CacheCalculator {
    static let shared = CacheCalculator()
    
    private init() {}
    
    /// 计算游戏资源缓存信息
    /// - Throws: GlobalError 当操作失败时
    func calculateMetaCacheInfo() throws -> CacheInfo {
        guard let metaDir = AppPaths.metaDirectory else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取元数据目录",
                i18nKey: "error.configuration.meta_directory_not_found",
                level: .notification
            )
        }
        
        let resourceTypes = AppConstants.cacheResourceTypes
        var totalFileCount = 0
        var totalSize: Int64 = 0
        
        for type in resourceTypes {
            let typeDir = metaDir.appendingPathComponent(type)
            let (fileCount, size) = try calculateDirectorySize(typeDir)
            totalFileCount += fileCount
            totalSize += size
        }
        
        return CacheInfo(fileCount: totalFileCount, totalSize: totalSize)
    }
    
    /// 计算应用缓存信息
    /// - Throws: GlobalError 当操作失败时
    func calculateCacheInfo() throws -> CacheInfo {
        guard let cacheDir = AppPaths.appCache else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取应用缓存目录",
                i18nKey: "error.configuration.app_cache_directory_not_found",
                level: .notification
            )
        }
        
        let (fileCount, size) = try calculateDirectorySize(cacheDir)
        return CacheInfo(fileCount: fileCount, totalSize: size)
    }
    
    /// 计算目录大小
    /// - Parameter directory: 目录路径
    /// - Returns: (文件数量, 总大小)
    /// - Throws: GlobalError 当操作失败时
    private func calculateDirectorySize(_ directory: URL) throws -> (fileCount: Int, size: Int64) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else {
            return (0, 0)
        }
        
        var fileCount = 0
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else {
            throw GlobalError.fileSystem(
                chineseMessage: "无法枚举目录: \(directory.path)",
                i18nKey: "error.filesystem.directory_enumeration_failed",
                level: .silent
            )
        }
        
        for case let fileURL as URL in enumerator {
            // 排除 .DS_Store 文件
            if fileURL.lastPathComponent == ".DS_Store" {
                continue
            }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resourceValues.fileSize {
                    fileCount += 1
                    totalSize += Int64(fileSize)
                }
            } catch {
                Logger.shared.warning("无法获取文件大小: \(fileURL.path), 错误: \(error.localizedDescription)")
                // 继续处理其他文件，不中断整个计算过程
            }
        }
        
        return (fileCount, totalSize)
    }
    
    /// 计算指定游戏 profile 下的缓存信息
    /// - Parameter gameName: 游戏名称
    /// - Returns: 缓存信息
    /// - Throws: GlobalError 当操作失败时
    func calculateProfileCacheInfo(gameName: String) throws -> CacheInfo {
        guard let profileDir = AppPaths.profileDirectory(gameName: gameName) else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取游戏配置目录: \(gameName)",
                i18nKey: "error.configuration.game_profile_directory_not_found",
                level: .notification
            )
        }
        
        let subdirectories = AppPaths.profileSubdirectories
        var totalFileCount = 0
        var totalSize: Int64 = 0
        
        for subdir in subdirectories {
            let subdirPath = profileDir.appendingPathComponent(subdir)
            let (fileCount, size) = try calculateDirectorySize(subdirPath)
            totalFileCount += fileCount
            totalSize += size
        }
        
        return CacheInfo(fileCount: totalFileCount, totalSize: totalSize)
    }
} 
