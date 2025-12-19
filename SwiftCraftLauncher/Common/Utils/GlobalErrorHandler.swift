import Foundation
import SwiftUI

// MARK: - Error Level Enum

/// 错误等级枚举
enum ErrorLevel: String, CaseIterable {
    case popup = "popup"           // 弹窗显示
    case notification = "notification" // 通知显示
    case silent = "silent"         // 静默处理，只记录日志
    case disabled = "disabled"     // 什么都不做，不记录

    var displayName: String {
        switch self {
        case .popup:
            return "弹窗"
        case .notification:
            return "通知"
        case .silent:
            return "静默"
        case .disabled:
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
        case let .network(message, key, _):
            return "network_\(key)_\(message.hashValue)"
        case let .fileSystem(message, key, _):
            return "filesystem_\(key)_\(message.hashValue)"
        case let .authentication(message, key, _):
            return "auth_\(key)_\(message.hashValue)"
        case let .validation(message, key, _):
            return "validation_\(key)_\(message.hashValue)"
        case let .download(message, key, _):
            return "download_\(key)_\(message.hashValue)"
        case let .installation(message, key, _):
            return "installation_\(key)_\(message.hashValue)"
        case let .gameLaunch(message, key, _):
            return "gameLaunch_\(key)_\(message.hashValue)"
        case let .resource(message, key, _):
            return "resource_\(key)_\(message.hashValue)"
        case let .player(message, key, _):
            return "player_\(key)_\(message.hashValue)"
        case let .configuration(message, key, _):
            return "config_\(key)_\(message.hashValue)"
        case let .unknown(message, key, _):
            return "unknown_\(key)_\(message.hashValue)"
        }
    }

    /// 中文错误描述
    var chineseMessage: String {
        switch self {
        case let .network(message, _, _):
            return message
        case let .fileSystem(message, _, _):
            return message
        case let .authentication(message, _, _):
            return message
        case let .validation(message, _, _):
            return message
        case let .download(message, _, _):
            return message
        case let .installation(message, _, _):
            return message
        case let .gameLaunch(message, _, _):
            return message
        case let .resource(message, _, _):
            return message
        case let .player(message, _, _):
            return message
        case let .configuration(message, _, _):
            return message
        case let .unknown(message, _, _):
            return message
        }
    }

    /// 国际化key
    var i18nKey: String {
        switch self {
        case let .network(_, key, _):
            return key
        case let .fileSystem(_, key, _):
            return key
        case let .authentication(_, key, _):
            return key
        case let .validation(_, key, _):
            return key
        case let .download(_, key, _):
            return key
        case let .installation(_, key, _):
            return key
        case let .gameLaunch(_, key, _):
            return key
        case let .resource(_, key, _):
            return key
        case let .player(_, key, _):
            return key
        case let .configuration(_, key, _):
            return key
        case let .unknown(_, key, _):
            return key
        }
    }

    /// 错误等级
    var level: ErrorLevel {
        switch self {
        case let .network(_, _, level):
            return level
        case let .fileSystem(_, _, level):
            return level
        case let .authentication(_, _, level):
            return level
        case let .validation(_, _, level):
            return level
        case let .download(_, _, level):
            return level
        case let .installation(_, _, level):
            return level
        case let .gameLaunch(_, _, level):
            return level
        case let .resource(_, _, level):
            return level
        case let .player(_, _, level):
            return level
        case let .configuration(_, _, level):
            return level
        case let .unknown(_, _, level):
            return level
        }
    }

    /// 本地化错误描述（使用国际化key）
    var errorDescription: String? {
        return i18nKey.localized()
    }

    /// 本地化描述（兼容性）
    var localizedDescription: String {
        // 如果chineseMessage不包含未格式化的占位符，说明已经格式化过，优先使用它
        if !chineseMessage.contains("%@") {
            return chineseMessage
        }
        // 否则使用errorDescription（如果它也不包含占位符）
        if let errorDesc = errorDescription, !errorDesc.contains("%@") {
            return errorDesc
        }
        // 如果都包含占位符，返回chineseMessage（至少是中文消息）
        return chineseMessage
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

        case .disabled:
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
    @StateObject private var errorHandler = GlobalErrorHandler.shared

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
