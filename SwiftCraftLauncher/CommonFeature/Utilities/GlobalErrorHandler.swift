//
//  GlobalErrorHandler.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import MinecraftFriendsKit
import SwiftUI

/// Defines how an error should be presented to the user.
enum ErrorLevel: String, CaseIterable {
    case popup
    case notification
    case silent
    case disabled

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

/// Categorizes errors by their domain.
enum GlobalErrorKind: String, CaseIterable {
    case network
    case fileSystem
    case authentication
    case validation
    case download
    case installation
    case gameLaunch
    case resource
    case player
    case configuration
    case unknown

    var defaultLevel: ErrorLevel {
        switch self {
        case .authentication, .gameLaunch:
            return .popup
        case .unknown:
            return .silent
        default:
            return .notification
        }
    }

    var idPrefix: String {
        switch self {
        case .network: return "network"
        case .fileSystem: return "filesystem"
        case .authentication: return "auth"
        case .validation: return "validation"
        case .download: return "download"
        case .installation: return "installation"
        case .gameLaunch: return "gameLaunch"
        case .resource: return "resource"
        case .player: return "player"
        case .configuration: return "config"
        case .unknown: return "unknown"
        }
    }

    var notificationTitleKey: String {
        switch self {
        case .network: return "error.notification.network.title"
        case .fileSystem: return "error.notification.filesystem.title"
        case .authentication: return "error.notification.authentication.title"
        case .validation: return "error.notification.validation.title"
        case .download: return "error.notification.download.title"
        case .installation: return "error.notification.installation.title"
        case .gameLaunch: return "error.notification.game_launch.title"
        case .resource: return "error.notification.resource.title"
        case .player: return "error.notification.player.title"
        case .configuration: return "error.notification.configuration.title"
        case .unknown: return "error.notification.unknown.title"
        }
    }

    var notificationTitle: String {
        notificationTitleKey.localized()
    }
}

/// A unified error type that carries category metadata, a localized message, and a display level.
struct GlobalError: Error, LocalizedError, Identifiable {
    let kind: GlobalErrorKind
    let chineseMessage: String
    let i18nKey: String
    let level: ErrorLevel
    let statusCode: Int?

    init(
        kind: GlobalErrorKind,
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel? = nil,
        statusCode: Int? = nil,
    ) {
        self.kind = kind
        self.chineseMessage = chineseMessage
        self.i18nKey = i18nKey
        self.level = level ?? kind.defaultLevel
        self.statusCode = statusCode
    }

    var id: String {
        "\(kind.idPrefix)_\(i18nKey)_\(chineseMessage.hashValue)"
    }

    var notificationTitle: String {
        kind.notificationTitle
    }

    var errorDescription: String? {
        i18nKey.localized()
    }

    /// Returns the localized description, falling back to the Chinese message if no localization is found.
    var localizedDescription: String {
        let localizedText = i18nKey.localized()
        if localizedText != i18nKey {
            return localizedText
        }
        return chineseMessage
    }
}

extension GlobalError {
    static func network(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification,
        statusCode: Int? = nil,
    ) -> GlobalError {
        GlobalError(kind: .network, chineseMessage: chineseMessage, i18nKey: i18nKey, level: level, statusCode: statusCode)
    }

    static func fileSystem(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification,
    ) -> GlobalError {
        GlobalError(kind: .fileSystem, chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }

    static func authentication(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .popup,
    ) -> GlobalError {
        GlobalError(kind: .authentication, chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }

    static func validation(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification,
    ) -> GlobalError {
        GlobalError(kind: .validation, chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }

    static func download(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification,
    ) -> GlobalError {
        GlobalError(kind: .download, chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }

    static func installation(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification,
    ) -> GlobalError {
        GlobalError(kind: .installation, chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }

    static func gameLaunch(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .popup,
    ) -> GlobalError {
        GlobalError(kind: .gameLaunch, chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }

    static func resource(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification,
    ) -> GlobalError {
        GlobalError(kind: .resource, chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }

    static func player(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification,
    ) -> GlobalError {
        GlobalError(kind: .player, chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }

    static func configuration(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .notification,
    ) -> GlobalError {
        GlobalError(kind: .configuration, chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }

    static func unknown(
        chineseMessage: String,
        i18nKey: String,
        level: ErrorLevel = .silent,
    ) -> GlobalError {
        GlobalError(kind: .unknown, chineseMessage: chineseMessage, i18nKey: i18nKey, level: level)
    }
}

extension GlobalError {
    /// Converts an arbitrary error into a ``GlobalError``.
    static func from(_ error: Error) -> GlobalError {
        switch error {
        case let globalError as Self:
            return globalError

        case let mf as MinecraftFriendsServiceError:
            return fromMinecraftFriendsServiceError(mf)

        default:
            if let urlError = error as? URLError {
                let level: ErrorLevel = urlError.code == .cancelled ? .silent : .notification
                return Self.network(
                    chineseMessage: urlError.localizedDescription,
                    i18nKey: "error.network.url",
                    level: level,
                )
            }

            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain {
                return Self.fileSystem(
                    chineseMessage: nsError.localizedDescription,
                    i18nKey: "error.filesystem.cocoa",
                    level: .notification,
                )
            }

            return Self.unknown(
                chineseMessage: error.localizedDescription,
                i18nKey: "error.unknown.generic",
                level: .silent,
            )
        }
    }

    private static func minecraftFriendsErrorLevel(_ level: MinecraftFriendsErrorLevel) -> ErrorLevel {
        switch level {
        case .popup: return .popup
        case .notification: return .notification
        case .silent: return .silent
        }
    }

    private static func fromMinecraftFriendsServiceError(_ error: MinecraftFriendsServiceError) -> GlobalError {
        switch error {
        case let .network(message, key, level):
            return Self.network(
                chineseMessage: message,
                i18nKey: key,
                level: minecraftFriendsErrorLevel(level),
            )
        case let .authentication(message, key, level):
            return Self.authentication(
                chineseMessage: message,
                i18nKey: key,
                level: minecraftFriendsErrorLevel(level),
            )
        case let .validation(message, key, level):
            return Self.validation(
                chineseMessage: message,
                i18nKey: key,
                level: minecraftFriendsErrorLevel(level),
            )
        }
    }
}

/// Manages global error state, including presentation and history.
class GlobalErrorHandler: ObservableObject {
    static let shared = GlobalErrorHandler()

    @Published var currentError: GlobalError?
    @Published var errorHistory: [GlobalError] = []

    private let maxHistoryCount = 100

    private init() { }

    func handle(_ error: Error) {
        let globalError = GlobalError.from(error)
        handle(globalError)
    }

    func handle(_ globalError: GlobalError) {
        DispatchQueue.main.async {
            self.currentError = globalError
            self.addToHistory(globalError)
            self.logError(globalError)
            self.handleErrorByLevel(globalError)
        }
    }

    private func handleErrorByLevel(_ error: GlobalError) {
        switch error.level {
        case .popup:
            AppLog.common.error("[GlobalError-Popup] \(error.chineseMessage)")

        case .notification:
            Task {
                await NotificationManager.sendSilently(
                    title: error.notificationTitle,
                    body: error.localizedDescription,
                )
            }

        case .silent:
            AppLog.common.error("[GlobalError-Silent] \(error.chineseMessage)")

        case .disabled:
            break
        }
    }

    /// Clears the currently displayed error.
    func clearCurrentError() {
        DispatchQueue.main.async {
            self.currentError = nil
        }
    }

    /// Clears the error history.
    func clearHistory() {
        DispatchQueue.main.async {
            self.errorHistory.removeAll()
        }
    }

    private func addToHistory(_ error: GlobalError) {
        errorHistory.append(error)

        if errorHistory.count > maxHistoryCount {
            errorHistory.removeFirst()
        }
    }

    /// Releases memory when the application is terminating.
    func cleanup() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.errorHistory.removeAll(keepingCapacity: false)
        }
    }

    private func logError(_ error: GlobalError) {
        AppLog.common.error("[GlobalError] \(error.chineseMessage) | Key: \(error.i18nKey) | Level: \(error.level.rawValue)")
    }
}

struct GlobalErrorHandlerModifier: ViewModifier {
    @StateObject private var errorHandler: GlobalErrorHandler

    init(errorHandler: GlobalErrorHandler = AppServices.errorHandler) {
        _errorHandler = StateObject(wrappedValue: errorHandler)
    }

    func body(content: Content) -> some View {
        content
            .onReceive(errorHandler.$currentError) { error in
                if let error {
                    AppLog.common.error("Global error occurred: \(error.chineseMessage)")
                }
            }
    }
}

extension View {
    func errorHandler() -> some View {
        modifier(GlobalErrorHandlerModifier())
    }
}
