//
//  NotificationManager.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import os
import UserNotifications

final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void,
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }
}

enum NotificationManager {
    /// Sends a local notification with the specified title and body.
    /// - Parameters:
    ///   - title: The notification title.
    ///   - body: The notification body text.
    /// - Throws: A `GlobalError` when the notification fails to send.
    static func send(title: String, body: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    Logger.shared.error("添加通知请求时出错：\(error.localizedDescription)")
                    continuation.resume(
                        throwing: GlobalError.resource(
                            chineseMessage: "发送通知失败: \(error.localizedDescription)",
                            i18nKey: "error.resource.notification_send_failed",
                            level: .silent,
                        ),
                    )
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    /// Sends a notification silently, logging errors instead of throwing.
    /// - Parameters:
    ///   - title: The notification title.
    ///   - body: The notification body text.
    static func sendSilently(title: String, body: String) async {
        do {
            try await send(title: title, body: body)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("发送通知失败: \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
        }
    }

    /// Requests authorization to display notifications.
    /// - Throws: A `GlobalError` when authorization is denied or fails.
    static func requestAuthorization() async throws {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])

            if granted {
                Logger.shared.info("通知权限已授予")
            } else {
                throw GlobalError.configuration(
                    chineseMessage: "用户拒绝了通知权限",
                    i18nKey: "error.configuration.notification_permission_denied",
                    level: .notification,
                )
            }
        } catch {
            if error is GlobalError {
                throw error
            } else {
                throw GlobalError.configuration(
                    chineseMessage: "请求通知权限失败: \(error.localizedDescription)",
                    i18nKey: "error.configuration.notification_permission_request_failed",
                    level: .notification,
                )
            }
        }
    }

    /// Requests notification authorization silently, logging errors instead of throwing.
    static func requestAuthorizationIfNeeded() async {
        do {
            try await requestAuthorization()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("请求通知权限失败: \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
        }
    }

    /// Returns the current notification authorization status.
    static func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Returns whether the app is authorized to send notifications.
    static func hasAuthorization() async -> Bool {
        let status = await checkAuthorizationStatus()
        return status == .authorized
    }
}
