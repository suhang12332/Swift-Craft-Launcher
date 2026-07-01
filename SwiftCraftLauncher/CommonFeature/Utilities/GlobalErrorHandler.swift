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
            return "Popup"
        case .notification:
            return "Notification"
        case .silent:
            return "Silent"
        case .disabled:
            return "Disabled"
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
    let i18nKey: String
    let level: ErrorLevel
    let statusCode: Int?

    init(
        kind: GlobalErrorKind,
        i18nKey: String,
        level: ErrorLevel? = nil,
        statusCode: Int? = nil,
    ) {
        self.kind = kind
        self.i18nKey = i18nKey
        self.level = level ?? kind.defaultLevel
        self.statusCode = statusCode
    }

    var id: String {
        "\(kind.idPrefix)_\(i18nKey)"
    }

    var notificationTitle: String {
        kind.notificationTitle
    }

    var errorDescription: String? {
        i18nKey.localized()
    }

    var localizedDescription: String {
        i18nKey.localized()
    }
}

extension GlobalError {
    static func network(
        i18nKey: String,
        level: ErrorLevel = .notification,
        statusCode: Int? = nil,
    ) -> GlobalError {
        GlobalError(kind: .network, i18nKey: i18nKey, level: level, statusCode: statusCode)
    }

    static func fileSystem(
        i18nKey: String,
        level: ErrorLevel = .notification,
    ) -> GlobalError {
        GlobalError(kind: .fileSystem, i18nKey: i18nKey, level: level)
    }

    static func authentication(
        i18nKey: String,
        level: ErrorLevel = .popup,
    ) -> GlobalError {
        GlobalError(kind: .authentication, i18nKey: i18nKey, level: level)
    }

    static func validation(
        i18nKey: String,
        level: ErrorLevel = .notification,
    ) -> GlobalError {
        GlobalError(kind: .validation, i18nKey: i18nKey, level: level)
    }

    static func download(
        i18nKey: String,
        level: ErrorLevel = .notification,
    ) -> GlobalError {
        GlobalError(kind: .download, i18nKey: i18nKey, level: level)
    }

    static func installation(
        i18nKey: String,
        level: ErrorLevel = .notification,
    ) -> GlobalError {
        GlobalError(kind: .installation, i18nKey: i18nKey, level: level)
    }

    static func gameLaunch(
        i18nKey: String,
        level: ErrorLevel = .popup,
    ) -> GlobalError {
        GlobalError(kind: .gameLaunch, i18nKey: i18nKey, level: level)
    }

    static func resource(
        i18nKey: String,
        level: ErrorLevel = .notification,
    ) -> GlobalError {
        GlobalError(kind: .resource, i18nKey: i18nKey, level: level)
    }

    static func player(
        i18nKey: String,
        level: ErrorLevel = .notification,
    ) -> GlobalError {
        GlobalError(kind: .player, i18nKey: i18nKey, level: level)
    }

    static func configuration(
        i18nKey: String,
        level: ErrorLevel = .notification,
    ) -> GlobalError {
        GlobalError(kind: .configuration, i18nKey: i18nKey, level: level)
    }

    static func unknown(
        i18nKey: String,
        level: ErrorLevel = .silent,
    ) -> GlobalError {
        GlobalError(kind: .unknown, i18nKey: i18nKey, level: level)
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
                    i18nKey: "error.network.url",
                    level: level,
                )
            }

            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain {
                return Self.fileSystem(
                    i18nKey: "error.filesystem.cocoa",
                    level: .notification,
                )
            }

            return Self.unknown(
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
        case let .network(_, key, level):
            return Self.network(
                i18nKey: key,
                level: minecraftFriendsErrorLevel(level),
            )
        case let .authentication(_, key, level):
            return Self.authentication(
                i18nKey: key,
                level: minecraftFriendsErrorLevel(level),
            )
        case let .validation(_, key, level):
            return Self.validation(
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
            AppLog.common.error("[GlobalError-Popup] \(error.localizedDescription)")

        case .notification:
            Task {
                await NotificationManager.sendSilently(
                    title: error.notificationTitle,
                    body: error.localizedDescription,
                )
            }

        case .silent:
            AppLog.common.error("[GlobalError-Silent] \(error.localizedDescription)")

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
        AppLog.common.error("[GlobalError] \(error.localizedDescription) | Key: \(error.i18nKey) | Level: \(error.level.rawValue)")
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
                    AppLog.common.error("Global error occurred: \(error.localizedDescription)")
                }
            }
    }
}

extension View {
    func errorHandler() -> some View {
        modifier(GlobalErrorHandlerModifier())
    }
}
