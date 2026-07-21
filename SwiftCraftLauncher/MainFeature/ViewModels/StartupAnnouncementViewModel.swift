//
//  StartupAnnouncementViewModel.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Manages startup announcement display and acknowledgment state.
@MainActor
@Observable final class StartupAnnouncementViewModel {
    var hasAnnouncement: Bool = false
    var announcementData: AnnouncementData?

    private var hasCheckedAnnouncement = false

    init() { }

    /// Checks for a new announcement if one hasn't been checked yet.
    func checkAnnouncementIfNeeded() async {
        guard !hasCheckedAnnouncement else { return }
        hasCheckedAnnouncement = true

        await Task(priority: .utility) { [weak self] in
            guard let self else { return }
            await checkAnnouncement()
        }.value
    }

    private func checkAnnouncement() async {
        if DIContainer.shared.ui.announcementStateManager.isAnnouncementAcknowledgedForCurrentVersion() {
            hasAnnouncement = false
            announcementData = nil
            return
        }

        let version = Bundle.main.appVersion
        let language = DIContainer.shared.ui.languageManager.selectedLanguage

        do {
            let data = try await DIContainer.shared.system.gitHubService.fetchAnnouncement(
                version: version,
                language: language,
            )

            if let data {
                hasAnnouncement = true
                announcementData = data
            } else {
                hasAnnouncement = false
                announcementData = nil
            }
        } catch {
            hasAnnouncement = false
            announcementData = nil
        }
    }
}
