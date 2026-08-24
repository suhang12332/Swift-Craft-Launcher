//
//  SparkleUpdateService.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Sparkle

/// Manages application updates using the Sparkle framework.
@Observable
final class SparkleUpdateService: NSObject, SPUUpdaterDelegate, @unchecked Sendable {
    private var updater: SPUUpdater?
    private var hasStartedUpdater = false
    private var hasScheduledStartupCheck = false

    var updateAvailable = false
    var versionString = ""

    private let startupCheckDelay: TimeInterval = 2.0

    override init() {
        super.init()
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
        let appcastURL = URLConfig.API.Sparkle.appcastURL(architecture: architecture)
        return appcastURL.absoluteString
    }

    func updaterDidNotFindUpdate(_: SPUUpdater) {
        AppLog.common.info("Check completed, no new version found")
        updateAvailable = false
    }

    func updater(_: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        AppLog.common.info("New version found: \(item.versionString)")
        updateAvailable = true
        versionString = item.displayVersionString
    }

    func updater(_: SPUUpdater, didFailToCheckForUpdatesWithError error: Error) {
        AppLog.common.error("Update check failed: \(error.localizedDescription)")
        updateAvailable = false
    }

    func updater(_: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        AppLog.common.info("Starting update installation: \(item.versionString)")
    }

    func updater(_: SPUUpdater, didFinishLoading _: SUAppcast) {
        AppLog.common.info("Update manifest loaded")
    }

    private func getSystemArchitecture() -> String {
        Architecture.current.sparkleArch
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

        updater.checkForUpdatesInBackground()
    }
}

/// Intercepts download requests to rewrite the URL to the configured download mirror.
extension SparkleUpdateService {
    func updater(_: SPUUpdater, willDownloadUpdate _: SUAppcastItem, with request: NSMutableURLRequest) {
        guard let originalURL = request.url else { return }

        let version = versionString
        guard !version.isEmpty else {
            AppLog.common.warning("Update download URL rewrite skipped: version is empty, using original URL")
            return
        }

        let fileName = originalURL.lastPathComponent
        let mirroredURL = URLConfig.API.Sparkle.downloadBaseURL
            .appendingPathComponent(version)
            .appendingPathComponent(fileName)

        AppLog.common.info("Update download URL rewritten: \(originalURL.absoluteString) -> \(mirroredURL.absoluteString)")
        request.url = mirroredURL
    }
}
