import Foundation
import SwiftUI

// MARK: - Error Level Enum

/// 错误等级枚举
enum ErrorLevel: String, CaseIterable {
    case popup = "popup"           // 弹窗显示
    case notification = "notification" // 通知显示
    case silent = "silent"         // 静默处理，只记录日志
    case none = "none"             // 什么都不做，不记录
    
    var displayName: String {
        switch self {
        case .popup:
            return "弹窗"
        case .notification:
            return "通知"
        case .silent:
            return "静默"
        case .none:
            return "无操作"
        }
    }
}

// MARK: - Global Error Types

/// 全局错误类型枚举
enum GlobalError: Error, LocalizedError, Identifiable {
    case network(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification
    )
    case fileSystem(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification
    )
    case authentication(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .popup
    )
    case validation(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification
    )
    case download(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification
    )
    case installation(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification
    )
    case gameLaunch(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .popup
    )
    case resource(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification
    )
    case player(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification
    )
    case configuration(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification
    )
    case unknown(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .silent
    )
    
    var id: String {
        switch self {
        case .network(let message, let key, _):
            return "network_\(key)_\(message.hashValue)"
        case .fileSystem(let message, let key, _):
            return "filesystem_\(key)_\(message.hashValue)"
        case .authentication(let message, let key, _):
            return "auth_\(key)_\(message.hashValue)"
        case .validation(let message, let key, _):
            return "validation_\(key)_\(message.hashValue)"
        case .download(let message, let key, _):
            return "download_\(key)_\(message.hashValue)"
        case .installation(let message, let key, _):
            return "installation_\(key)_\(message.hashValue)"
        case .gameLaunch(let message, let key, _):
            return "gameLaunch_\(key)_\(message.hashValue)"
        case .resource(let message, let key, _):
            return "resource_\(key)_\(message.hashValue)"
        case .player(let message, let key, _):
            return "player_\(key)_\(message.hashValue)"
        case .configuration(let message, let key, _):
            return "config_\(key)_\(message.hashValue)"
        case .unknown(let message, let key, _):
            return "unknown_\(key)_\(message.hashValue)"
        }
    }
    
    /// 中文错误描述
    var chineseMessage: String {
        switch self {
        case .network(let message, _, _):
            return message
        case .fileSystem(let message, _, _):
            return message
        case .authentication(let message, _, _):
            return message
        case .validation(let message, _, _):
            return message
        case .download(let message, _, _):
            return message
        case .installation(let message, _, _):
            return message
        case .gameLaunch(let message, _, _):
            return message
        case .resource(let message, _, _):
            return message
        case .player(let message, _, _):
            return message
        case .configuration(let message, _, _):
            return message
        case .unknown(let message, _, _):
            return message
        }
    }
    
    /// 国际化key
    var i18nKey: String {
        switch self {
        case .network(_, let key, _):
            return key
        case .fileSystem(_, let key, _):
            return key
        case .authentication(_, let key, _):
            return key
        case .validation(_, let key, _):
            return key
        case .download(_, let key, _):
            return key
        case .installation(_, let key, _):
            return key
        case .gameLaunch(_, let key, _):
            return key
        case .resource(_, let key, _):
            return key
        case .player(_, let key, _):
            return key
        case .configuration(_, let key, _):
            return key
        case .unknown(_, let key, _):
            return key
        }
    }
    
    /// 错误等级
    var level: ErrorLevel {
        switch self {
        case .network(_, _, let level):
            return level
        case .fileSystem(_, _, let level):
            return level
        case .authentication(_, _, let level):
            return level
        case .validation(_, _, let level):
            return level
        case .download(_, _, let level):
            return level
        case .installation(_, _, let level):
            return level
        case .gameLaunch(_, _, let level):
            return level
        case .resource(_, _, let level):
            return level
        case .player(_, _, let level):
            return level
        case .configuration(_, _, let level):
            return level
        case .unknown(_, _, let level):
            return level
        }
    }
    
    /// 本地化错误描述（使用国际化key）
    var errorDescription: String? {
        return i18nKey.localized()
    }
    
    /// 本地化描述（兼容性）
    var localizedDescription: String {
        return errorDescription ?? chineseMessage
    }
    
    /// 获取通知标题（使用国际化key）
    var notificationTitle: String {
        switch self {
        case .network:
            return "error.notification.network.title".localized()
        case .fileSystem:
            return "error.notification.filesystem.title".localized()
        case .authentication:
            return "error.notification.authentication.title".localized()
        case .validation:
            return "error.notification.validation.title".localized()
        case .download:
            return "error.notification.download.title".localized()
        case .installation:
            return "error.notification.installation.title".localized()
        case .gameLaunch:
            return "error.notification.game_launch.title".localized()
        case .resource:
            return "error.notification.resource.title".localized()
        case .player:
            return "error.notification.player.title".localized()
        case .configuration:
            return "error.notification.configuration.title".localized()
        case .unknown:
            return "error.notification.unknown.title".localized()
        }
    }
}

// MARK: - Error Conversion Extensions

extension GlobalError {
    /// 从其他错误类型转换为全局错误
    static func from(_ error: Error) -> GlobalError {
        switch error {
        case let globalError as GlobalError:
            return globalError
            
        case let authError as MinecraftAuthError:
            return .authentication(
                chineseMessage: authError.localizedDescription,
                i18nKey: "error.authentication.minecraft",
                level: .popup
            )
            
        default:
            // 检查是否是网络相关错误
            if let urlError = error as? URLError {
                return .network(
                    chineseMessage: urlError.localizedDescription,
                    i18nKey: "error.network.url",
                    level: .notification
                )
            }
            
            // 检查是否是文件系统错误
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain {
                return .fileSystem(
                    chineseMessage: nsError.localizedDescription,
                    i18nKey: "error.filesystem.cocoa",
                    level: .notification
                )
            }
            
            return .unknown(
                chineseMessage: error.localizedDescription,
                i18nKey: "error.unknown.generic",
                level: .silent
            )
        }
    }
}

// MARK: - Global Error Handler

/// 全局错误处理器
class GlobalErrorHandler: ObservableObject {
    static let shared = GlobalErrorHandler()
    
    @Published var currentError: GlobalError?
    @Published var errorHistory: [GlobalError] = []
    
    private let maxHistoryCount = 100
    
    private init() {}
    
    /// 处理错误
    /// - Parameter error: 要处理的错误
    func handle(_ error: Error) {
        let globalError = GlobalError.from(error)
        handle(globalError)
    }
    
    /// 处理全局错误
    /// - Parameter globalError: 全局错误
    func handle(_ globalError: GlobalError) {
        DispatchQueue.main.async {
            self.currentError = globalError
            self.addToHistory(globalError)
            self.logError(globalError)
            self.handleErrorByLevel(globalError)
        }
    }
    
    /// 根据错误等级处理错误
    private func handleErrorByLevel(_ error: GlobalError) {
        switch error.level {
        case .popup:
            // 弹窗显示 - 通过 @Published 属性触发 UI 更新
            Logger.shared.error("[GlobalError-Popup] \(error.chineseMessage)")
            // 弹窗显示逻辑由 ErrorAlertModifier 处理
            
        case .notification:
            // 发送通知
            NotificationManager.sendSilently(
                title: error.notificationTitle,
                body: error.localizedDescription
            )
            
        case .silent:
            // 静默处理，只记录日志
            Logger.shared.error("[GlobalError-Silent] \(error.chineseMessage)")
            
        case .none:
            // 什么都不做
            break
        }
    }
    
    /// 清除当前错误
    func clearCurrentError() {
        DispatchQueue.main.async {
            self.currentError = nil
        }
    }
    
    /// 清除错误历史
    func clearHistory() {
        DispatchQueue.main.async {
            self.errorHistory.removeAll()
        }
    }
    
    /// 添加错误到历史记录
    private func addToHistory(_ error: GlobalError) {
        errorHistory.append(error)
        
        // 限制历史记录数量
        if errorHistory.count > maxHistoryCount {
            errorHistory.removeFirst()
        }
    }
    
    /// 清理内存（用于应用退出时）
    func cleanup() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.errorHistory.removeAll(keepingCapacity: false)
        }
    }
    
    /// 记录错误到日志
    private func logError(_ error: GlobalError) {
        Logger.shared.error("[GlobalError] \(error.chineseMessage) | Key: \(error.i18nKey) | Level: \(error.level.rawValue)")
    }
}

// MARK: - Error Handling View Modifier

/// 错误处理视图修饰符（已废弃，使用 errorAlert() 替代）
struct GlobalErrorHandlerModifier: ViewModifier {
    @ObservedObject private var errorHandler = GlobalErrorHandler.shared
    
    func body(content: Content) -> some View {
        content
            .onReceive(errorHandler.$currentError) { error in
                if let error = error {
                    // 只记录日志，弹窗由 ErrorAlertModifier 处理
                    Logger.shared.error("Global error occurred: \(error.chineseMessage)")
                }
            }
    }
}

// MARK: - View Extension

extension View {
    /// 添加全局错误处理（已废弃，使用 errorAlert() 替代）
    func globalErrorHandler() -> some View {
        self.modifier(GlobalErrorHandlerModifier())
    }
}

// MARK: - Convenience Methods

extension GlobalErrorHandler {
    /// 网络错误
    static func network(_ chineseMessage: String, i18nKey: String, level: ErrorLevel = .notification) -> GlobalError {
        return .network(chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }
    
    /// 文件系统错误
    static func fileSystem(_ chineseMessage: String, i18nKey: String, level: ErrorLevel = .notification) -> GlobalError {
        return .fileSystem(chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }
    
    /// 认证错误
    static func authentication(_ chineseMessage: String, i18nKey: String, level: ErrorLevel = .popup) -> GlobalError {
        return .authentication(chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }
    
    /// 验证错误
    static func validation(_ chineseMessage: String, i18nKey: String, level: ErrorLevel = .notification) -> GlobalError {
        return .validation(chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }
    
    /// 下载错误
    static func download(_ chineseMessage: String, i18nKey: String, level: ErrorLevel = .notification) -> GlobalError {
        return .download(chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }
    
    /// 安装错误
    static func installation(_ chineseMessage: String, i18nKey: String, level: ErrorLevel = .notification) -> GlobalError {
        return .installation(chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }
    
    /// 游戏启动错误
    static func gameLaunch(_ chineseMessage: String, i18nKey: String, level: ErrorLevel = .popup) -> GlobalError {
        return .gameLaunch(chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }
    
    /// 资源错误
    static func resource(_ chineseMessage: String, i18nKey: String, level: ErrorLevel = .notification) -> GlobalError {
        return .resource(chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }
    
    /// 玩家错误
    static func player(_ chineseMessage: String, i18nKey: String, level: ErrorLevel = .notification) -> GlobalError {
        return .player(chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }
    
    /// 配置错误
    static func configuration(_ chineseMessage: String, i18nKey: String, level: ErrorLevel = .notification) -> GlobalError {
        return .configuration(chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }
    
    /// 未知错误
    static func unknown(_ chineseMessage: String, i18nKey: String, level: ErrorLevel = .silent) -> GlobalError {
        return .unknown(chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }
}
