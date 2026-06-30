//
//  SparkleUpdateService.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Sparkle

/// Manages application updates using the Sparkle framework.
class SparkleUpdateService: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = SparkleUpdateService()

    private var updater: SPUUpdater?
    private var hasStartedUpdater = false
    private var hasScheduledStartupCheck = false

    @Published var isCheckingForUpdates = false
    @Published var updateAvailable = false
    @Published var currentVersion = ""
    @Published var latestVersion = ""
    @Published var updateDescription = ""
    @Published var versionString = ""

    private let startupCheckDelay: TimeInterval = 2.0

    override private init() {
        super.init()
        currentVersion = Bundle.main.appVersion
    }

    /// Configures and starts the Sparkle updater.
    private func setupUpdater() {
        let hostBundle = Bundle.main
        let driver = SPUStandardUserDriver(hostBundle: hostBundle, delegate: nil)

        do {
            updater = SPUUpdater(hostBundle: hostBundle, applicationBundle: hostBundle, userDriver: driver, delegate: self)

            try updater?.start()

            updater?.automaticallyChecksForUpdates = true
            updater?.updateCheckInterval = 24 * 60 * 60
            updater?.sendsSystemProfile = false
        } catch {
            Logger.shared.error("初始化更新器失败：\(error.localizedDescription)")
        }
    }

    private func ensureUpdaterStarted() {
        guard !hasStartedUpdater else { return }
        hasStartedUpdater = true
        setupUpdater()
    }

    func feedURLString(for _: SPUUpdater) -> String? {
        let architecture = getSystemArchitecture()
        let appcastURL = URLConfig.API.GitHub.appcastURL(architecture: architecture)
        return appcastURL.absoluteString
    }

    func updaterDidNotFindUpdate(_: SPUUpdater) {
        Logger.shared.info("检查完成，未发现新版本")
        isCheckingForUpdates = false
        updateAvailable = false
    }

    func updater(_: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Logger.shared.info("发现新版本：\(item.versionString)")
        isCheckingForUpdates = false
        updateAvailable = true
        latestVersion = item.versionString
        versionString = item.displayVersionString
        updateDescription = item.itemDescription ?? ""
    }

    func updater(_: SPUUpdater, didFailToCheckForUpdatesWithError error: Error) {
        Logger.shared.error("更新检查失败：\(error.localizedDescription)")
        isCheckingForUpdates = false
        updateAvailable = false
    }

    func updater(_: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        Logger.shared.info("开始安装更新：\(item.versionString)")
        isCheckingForUpdates = false
    }

    func updater(_: SPUUpdater, didFinishLoading _: SUAppcast) {
        Logger.shared.info("更新清单加载完成")
    }

    private func getSystemArchitecture() -> String {
        Architecture.current.sparkleArch
    }

    /// Returns the current system architecture identifier.
    func getCurrentArchitecture() -> String {
        getSystemArchitecture()
    }

    /// Returns the current updater state.
    func getUpdaterStatus() -> (isInitialized: Bool, sessionInProgress: Bool, isChecking: Bool) {
        guard let updater else {
            return (isInitialized: false, sessionInProgress: false, isChecking: isCheckingForUpdates)
        }
        return (isInitialized: true, sessionInProgress: updater.sessionInProgress, isChecking: isCheckingForUpdates)
    }

    func scheduleStartupCheckIfNeeded() {
        guard !hasScheduledStartupCheck else { return }
        hasScheduledStartupCheck = true
        DispatchQueue.main.asyncAfter(deadline: .now() + startupCheckDelay) { [weak self] in
            self?.checkForUpdatesSilently()
        }
    }

    /// Checks for updates and displays the standard Sparkle UI.
    func checkForUpdatesWithUI() {
        ensureUpdaterStarted()
        guard let updater else {
            Logger.shared.error("更新器尚未初始化")
            return
        }

        if updater.sessionInProgress {
            Logger.shared.warning("更新会话正在进行中，跳过重复的更新检查")
            return
        }

        isCheckingForUpdates = true

        updater.checkForUpdates()
    }

    /// Checks for updates silently without showing any UI.
    func checkForUpdatesSilently() {
        ensureUpdaterStarted()
        guard let updater else {
            Logger.shared.error("更新器尚未初始化")
            return
        }

        if updater.sessionInProgress {
            Logger.shared.warning("更新会话正在进行中，跳过重复的更新检查")
            return
        }

        isCheckingForUpdates = true

        updater.checkForUpdatesInBackground()
    }
}

/// Intercepts download requests to apply proxy prefix for GitHub resource URLs when needed.
extension SparkleUpdateService {
    func updater(_: SPUUpdater, willDownloadUpdate _: SUAppcastItem, with request: NSMutableURLRequest) {
        guard let originalURL = request.url else { return }

        let proxiedURL = URLConfig.applyGitProxyIfNeeded(originalURL)
        if proxiedURL != originalURL {
            Logger.shared.info("更新下载链接已重写：\(originalURL.absoluteString) -> \(proxiedURL.absoluteString)")
            request.url = proxiedURL
        }
    }
}
