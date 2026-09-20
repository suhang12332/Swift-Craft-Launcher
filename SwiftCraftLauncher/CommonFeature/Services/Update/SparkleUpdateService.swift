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
    private var periodicCheckTimer: Timer?
    private let sourceSelector: UpdateSourceSelector
    private let selectedSourceLock = NSLock()
    private var selectedSourceStorage: UpdateSource
    private var activeSessionSourceStorage: UpdateSource

    var updateAvailable = false
    var versionString = ""

    private let startupCheckDelay: TimeInterval = 2.0
    private let periodicCheckInterval: TimeInterval = 24 * 60 * 60

    override convenience init() {
        let fallbackSource = URLConfig.API.Sparkle.defaultSource
        self.init(
            sourceSelector: UpdateSourceSelector(
                sources: URLConfig.API.Sparkle.updateSources,
                fallbackSource: fallbackSource,
            ),
            initialSource: fallbackSource,
        )
    }

    init(sourceSelector: UpdateSourceSelector, initialSource: UpdateSource) {
        self.sourceSelector = sourceSelector
        selectedSourceStorage = initialSource
        activeSessionSourceStorage = initialSource
        super.init()
    }

    private var selectedSource: UpdateSource {
        selectedSourceLock.withLock { selectedSourceStorage }
    }

    private var activeSessionSource: UpdateSource {
        selectedSourceLock.withLock { activeSessionSourceStorage }
    }

    private func selectUpdateSource() async {
        let architecture = getSystemArchitecture()
        let source = await sourceSelector.selectSource(architecture: architecture)
        selectedSourceLock.withLock {
            selectedSourceStorage = source
        }
        AppLog.common.info("Selected update source: \(source.name) (\(source.appcastURL(architecture: architecture).absoluteString))")
    }

    /// Configures and starts the Sparkle updater.
    @MainActor
    private func setupUpdater() {
        let hostBundle = Bundle.main
        let driver = SPUStandardUserDriver(hostBundle: hostBundle, delegate: nil)

        do {
            updater = SPUUpdater(hostBundle: hostBundle, applicationBundle: hostBundle, userDriver: driver, delegate: self)

            try updater?.start()

            // Schedule checks here so every automatic check refreshes the source asynchronously first.
            updater?.automaticallyChecksForUpdates = false
            updater?.sendsSystemProfile = false
            schedulePeriodicChecks()
        } catch {
            AppLog.common.error("Failed to initialize updater: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func ensureUpdaterStarted() {
        guard !hasStartedUpdater else { return }
        hasStartedUpdater = true
        setupUpdater()
    }

    @MainActor
    private func schedulePeriodicChecks() {
        guard periodicCheckTimer == nil else { return }
        periodicCheckTimer = Timer.scheduledTimer(withTimeInterval: periodicCheckInterval, repeats: true) { [weak self] _ in
            self?.checkForUpdatesSilently()
        }
        periodicCheckTimer?.tolerance = 60
    }

    func feedURLString(for _: SPUUpdater) -> String? {
        let architecture = getSystemArchitecture()
        let appcastURL = activeSessionSource.appcastURL(architecture: architecture)
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
        Task { [weak self] in
            guard let self else { return }
            await selectUpdateSource()
            await performUpdateCheck(displaysUI: true)
        }
    }

    /// Checks for updates silently without showing any UI.
    func checkForUpdatesSilently() {
        Task { [weak self] in
            guard let self else { return }
            await selectUpdateSource()
            await performUpdateCheck(displaysUI: false)
        }
    }

    @MainActor
    private func performUpdateCheck(displaysUI: Bool) {
        ensureUpdaterStarted()
        guard let updater else {
            AppLog.common.error("Updater not yet initialized")
            return
        }

        if updater.sessionInProgress {
            AppLog.common.error("Update session in progress, skipping duplicate update check")
            return
        }

        let source = selectedSource
        selectedSourceLock.withLock {
            activeSessionSourceStorage = source
        }

        if displaysUI {
            updater.checkForUpdates()
        } else {
            updater.checkForUpdatesInBackground()
        }
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
        let source = activeSessionSource
        let mirroredURL = source.downloadURL(version: version, fileName: fileName)

        AppLog.common.info("Update download URL rewritten via \(source.name): \(originalURL.absoluteString) -> \(mirroredURL.absoluteString)")
        request.url = mirroredURL
    }
}
