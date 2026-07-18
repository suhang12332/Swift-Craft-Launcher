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

    override init() {
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
            AppLog.common.error("Failed to initialize updater: \(error.localizedDescription)")
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
        AppLog.common.info("Check completed, no new version found")
        isCheckingForUpdates = false
        updateAvailable = false
    }

    func updater(_: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        AppLog.common.info("New version found: \(item.versionString)")
        isCheckingForUpdates = false
        updateAvailable = true
        latestVersion = item.versionString
        versionString = item.displayVersionString
        updateDescription = item.itemDescription ?? ""
    }

    func updater(_: SPUUpdater, didFailToCheckForUpdatesWithError error: Error) {
        AppLog.common.error("Update check failed: \(error.localizedDescription)")
        isCheckingForUpdates = false
        updateAvailable = false
    }

    func updater(_: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        AppLog.common.info("Starting update installation: \(item.versionString)")
        isCheckingForUpdates = false
    }

    func updater(_: SPUUpdater, didFinishLoading _: SUAppcast) {
        AppLog.common.info("Update manifest loaded")
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
            AppLog.common.error("Updater not yet initialized")
            return
        }

        if updater.sessionInProgress {
            AppLog.common.error("Update session in progress, skipping duplicate update check")
            return
        }

        isCheckingForUpdates = true

        updater.checkForUpdates()
    }

    /// Checks for updates silently without showing any UI.
    func checkForUpdatesSilently() {
        ensureUpdaterStarted()
        guard let updater else {
            AppLog.common.error("Updater not yet initialized")
            return
        }

        if updater.sessionInProgress {
            AppLog.common.error("Update session in progress, skipping duplicate update check")
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
            AppLog.common.info("Update download URL rewritten: \(originalURL.absoluteString) -> \(proxiedURL.absoluteString)")
            request.url = proxiedURL
        }
    }
}
