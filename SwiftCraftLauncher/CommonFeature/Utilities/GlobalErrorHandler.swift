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
    let message: String?

    init(
        kind: GlobalErrorKind,
        i18nKey: String,
        level: ErrorLevel? = nil,
        statusCode: Int? = nil,
        message: String? = nil,
    ) {
        self.kind = kind
        self.i18nKey = i18nKey
        self.level = level ?? kind.defaultLevel
        self.statusCode = statusCode
        self.message = message
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

    /// fallback for logging / debugging
    var description: String {
        message ?? i18nKey.localized()
    }
}

extension GlobalError {
    static func network(
        i18nKey: String,
        level: ErrorLevel = .notification,
        statusCode: Int? = nil,
        message: String? = nil,
    ) -> GlobalError {
        GlobalError(kind: .network, i18nKey: i18nKey, level: level, statusCode: statusCode, message: message)
    }

    static func fileSystem(
        i18nKey: String,
        level: ErrorLevel = .notification,
        message: String? = nil,
    ) -> GlobalError {
        GlobalError(kind: .fileSystem, i18nKey: i18nKey, level: level, message: message)
    }

    static func authentication(
        i18nKey: String,
        level: ErrorLevel = .popup,
        message: String? = nil,
    ) -> GlobalError {
        GlobalError(kind: .authentication, i18nKey: i18nKey, level: level, message: message)
    }

    static func validation(
        i18nKey: String,
        level: ErrorLevel = .notification,
        message: String? = nil,
    ) -> GlobalError {
        GlobalError(kind: .validation, i18nKey: i18nKey, level: level, message: message)
    }

    static func download(
        i18nKey: String,
        level: ErrorLevel = .notification,
        message: String? = nil,
    ) -> GlobalError {
        GlobalError(kind: .download, i18nKey: i18nKey, level: level, message: message)
    }

    static func installation(
        i18nKey: String,
        level: ErrorLevel = .notification,
        message: String? = nil,
    ) -> GlobalError {
        GlobalError(kind: .installation, i18nKey: i18nKey, level: level, message: message)
    }

    static func gameLaunch(
        i18nKey: String,
        level: ErrorLevel = .popup,
        message: String? = nil,
    ) -> GlobalError {
        GlobalError(kind: .gameLaunch, i18nKey: i18nKey, level: level, message: message)
    }

    static func resource(
        i18nKey: String,
        level: ErrorLevel = .notification,
        message: String? = nil,
    ) -> GlobalError {
        GlobalError(kind: .resource, i18nKey: i18nKey, level: level, message: message)
    }

    static func player(
        i18nKey: String,
        level: ErrorLevel = .notification,
        message: String? = nil,
    ) -> GlobalError {
        GlobalError(kind: .player, i18nKey: i18nKey, level: level, message: message)
    }

    static func configuration(
        i18nKey: String,
        level: ErrorLevel = .notification,
        message: String? = nil,
    ) -> GlobalError {
        GlobalError(kind: .configuration, i18nKey: i18nKey, level: level, message: message)
    }

    static func unknown(
        i18nKey: String,
        level: ErrorLevel = .silent,
        message: String? = nil,
    ) -> GlobalError {
        GlobalError(kind: .unknown, i18nKey: i18nKey, level: level, message: message)
    }
}

extension GlobalError {
    /// Converts an arbitrary error into a GlobalError.
    static func from(_ error: Error) -> GlobalError {
        switch error {
        case let globalError as Self:
            return globalError

        case let mf as MinecraftFriendsServiceError:
            return fromMinecraftFriendsServiceError(mf)

        default:
            if let urlError = error as? URLError {
                let level: ErrorLevel = urlError.code == .cancelled ? .silent : .notification
                return .network(i18nKey: "error.network.url", level: level)
            }

            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain {
                return .fileSystem(i18nKey: "error.filesystem.cocoa")
            }

            return .unknown(i18nKey: "error.unknown.generic", level: .silent)
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
            return .network(i18nKey: key, level: minecraftFriendsErrorLevel(level))

        case let .authentication(_, key, level):
            return .authentication(i18nKey: key, level: minecraftFriendsErrorLevel(level))

        case let .validation(_, key, level):
            return .validation(i18nKey: key, level: minecraftFriendsErrorLevel(level))
        }
    }
}

/// Manages global error state, including presentation and history.
class GlobalErrorHandler: ObservableObject {
    static let shared = GlobalErrorHandler()

    @Published var currentError: GlobalError?
    @Published var errorHistory: [GlobalError] = []

    private let maxHistoryCount = 100

    private var lastErrorId: String?
    private var lastErrorTime: Date = .distantPast
    private let deduplicationWindow: TimeInterval = 3.0

    private var recentErrorTimestamps: [Date] = []
    private let maxErrorsPerWindow = 5
    private let rateLimitWindow: TimeInterval = 10.0

    private init() { }

    func handle(_ error: Error) {
        handle(GlobalError.from(error))
    }

    func handle(_ globalError: GlobalError) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let now = Date()

            if globalError.id == lastErrorId,
               now.timeIntervalSince(lastErrorTime) < deduplicationWindow {
                return
            }

            pruneTimestamps(before: now)
            if recentErrorTimestamps.count >= maxErrorsPerWindow {
                return
            }

            lastErrorId = globalError.id
            lastErrorTime = now
            recentErrorTimestamps.append(now)

            currentError = globalError
            addToHistory(globalError)
            logError(globalError)
            handleErrorByLevel(globalError)
        }
    }

    private func pruneTimestamps(before cutoff: Date) {
        let threshold = cutoff.addingTimeInterval(-rateLimitWindow)
        recentErrorTimestamps.removeAll { $0 < threshold }
    }

    private func handleErrorByLevel(_ error: GlobalError) {
        switch error.level {
        case .popup:
            AppLog.common.error("[GlobalError-Popup] \(error.description)")

        case .notification:
            Task {
                await NotificationManager.sendSilently(
                    title: error.notificationTitle,
                    body: error.localizedDescription,
                )
            }

        case .silent:
            AppLog.common.error("[GlobalError-Silent] \(error.description)")

        case .disabled:
            break
        }
    }

    func clearCurrentError() {
        DispatchQueue.main.async {
            self.currentError = nil
        }
    }

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

    func cleanup() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.errorHistory.removeAll(keepingCapacity: false)
            self.lastErrorId = nil
            self.recentErrorTimestamps.removeAll(keepingCapacity: false)
        }
    }

    private func logError(_ error: GlobalError) {
        AppLog.common.error("[GlobalError] \(error.description) | Key: \(error.i18nKey) | Level: \(error.level.rawValue)")
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
                    AppLog.common.error("Global error occurred: \(error.description)")
                }
            }
    }
}

extension View {
    func errorHandler() -> some View {
        modifier(GlobalErrorHandlerModifier())
    }
}
