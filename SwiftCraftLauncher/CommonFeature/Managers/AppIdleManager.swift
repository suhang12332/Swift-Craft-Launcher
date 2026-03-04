import Foundation
import SwiftUI
import AppKit

extension Notification.Name {
    static let appDidEnterIdleFreeze = Notification.Name("app.didEnterIdleFreeze")
    static let appDidExitIdleFreeze = Notification.Name("app.didExitIdleFreeze")
}

@MainActor
final class AppIdleManager: ObservableObject {
    static let shared = AppIdleManager()

    @Published private(set) var isFrozen: Bool = false

    private var lastActivityAt: Date = Date()
    private var localMonitor: Any?
    private var idleCheckTimer: Timer?
    private var isMonitoringStarted = false

    private let idleThreshold: TimeInterval = 180
    private let checkInterval: TimeInterval = 15

    private init() {}

    func startMonitoring() {
        guard !isMonitoringStarted else { return }
        isMonitoringStarted = true
        lastActivityAt = Date()
        setupEventMonitor()
        setupIdleTimer()
    }

    func stopMonitoring() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        idleCheckTimer?.invalidate()
        idleCheckTimer = nil
        isMonitoringStarted = false
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            markUserActivity()
        case .inactive, .background:
            freezeIfNeeded()
        @unknown default:
            break
        }
    }

    func markUserActivity() {
        lastActivityAt = Date()
        if isFrozen {
            isFrozen = false
            NotificationCenter.default.post(name: .appDidExitIdleFreeze, object: nil)
            Logger.shared.debug("应用从空闲冻结恢复")
        }
    }

    private func setupEventMonitor() {
        let mask: NSEvent.EventTypeMask = [
            .keyDown, .leftMouseDown, .rightMouseDown,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged,
            .scrollWheel, .otherMouseDown, .otherMouseDragged,
        ]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in
                self?.markUserActivity()
            }
            return event
        }
    }

    private func setupIdleTimer() {
        idleCheckTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateIdleState()
            }
        }
    }

    private func evaluateIdleState() {
        guard NSApp.isActive else { return }
        let idleDuration = Date().timeIntervalSince(lastActivityAt)
        if idleDuration >= idleThreshold {
            freezeIfNeeded()
        }
    }

    private func freezeIfNeeded() {
        guard !isFrozen else { return }
        isFrozen = true
        releaseMemoryForIdleState()
        NotificationCenter.default.post(name: .appDidEnterIdleFreeze, object: nil)
        Logger.shared.debug("应用进入空闲冻结，已执行内存释放")
    }

    private func releaseMemoryForIdleState() {
        GameIconCache.shared.clearAllCache()
        ResourceImageCacheManager.shared.clearMemoryCache()
        ContributorAvatarCache.shared.clearCache()
        StaticContributorAvatarCache.shared.clearCache()
        MinecraftSkinUtils.clearCache()

        if !isWindowVisible(.aiChat) {
            WindowDataStore.shared.cleanup(for: .aiChat)
        }
        if !isWindowVisible(.skinPreview) {
            WindowDataStore.shared.cleanup(for: .skinPreview)
        }
    }

    private func isWindowVisible(_ id: WindowID) -> Bool {
        for window in NSApplication.shared.windows {
            if window.identifier?.rawValue == id.rawValue, window.isVisible {
                return true
            }
        }
        return false
    }
}
