import Foundation
import UserNotifications
import os

// MARK: - Notification Center Delegate

final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// App 在前台时收到通知，决定如何展示
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 允许在前台显示横幅 / 列表，并播放声音与更新徽标
        completionHandler([.banner, .list, .sound, .badge])
    }
}

enum NotificationManager {

    /// 发送通知
    /// - Parameters:
    ///   - title: 通知标题
    ///   - body: 通知内容
    /// - Throws: GlobalError 当操作失败时
    static func send(title: String, body: String) throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        let semaphore = DispatchSemaphore(value: 0)
        var notificationError: Error?

        UNUserNotificationCenter.current().add(request) { error in
            notificationError = error
            semaphore.signal()
        }

        semaphore.wait()

        if let error = notificationError {
            Logger.shared.error("添加通知请求时出错：\(error.localizedDescription)")
            throw GlobalError.resource(
                chineseMessage: "发送通知失败: \(error.localizedDescription)",
                i18nKey: "error.resource.notification_send_failed",
                level: .silent
            )
        }
    }

    /// 发送通知（静默版本，失败时记录错误但不抛出异常）
    /// - Parameters:
    ///   - title: 通知标题
    ///   - body: 通知内容
    static func sendSilently(title: String, body: String) {
        do {
            try send(title: title, body: body)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("发送通知失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
        }
    }

    /// 请求通知权限
    /// - Throws: GlobalError 当操作失败时
    static func requestAuthorization() async throws {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])

            if granted {
                Logger.shared.info("通知权限已授予")
            } else {
                Logger.shared.warning("用户拒绝了通知权限")
                throw GlobalError.configuration(
                    chineseMessage: "用户拒绝了通知权限",
                    i18nKey: "error.configuration.notification_permission_denied",
                    level: .notification
                )
            }
        } catch {
            Logger.shared.error("请求通知权限时出错: \(error.localizedDescription)")
            if error is GlobalError {
                throw error
            } else {
                throw GlobalError.configuration(
                    chineseMessage: "请求通知权限失败: \(error.localizedDescription)",
                    i18nKey: "error.configuration.notification_permission_request_failed",
                    level: .notification
                )
            }
        }
    }

    /// 请求通知权限（静默版本，失败时记录错误但不抛出异常）
    static func requestAuthorizationIfNeeded() async {
        do {
            try await requestAuthorization()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("请求通知权限失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
        }
    }

    /// - Returns: 权限状态
    static func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        return await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// 检查是否有通知权限
    /// - Returns: 是否有权限
    static func hasAuthorization() async -> Bool {
        let status = await checkAuthorizationStatus()
        return status == .authorized
    }
}
