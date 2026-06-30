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
final class StartupAnnouncementViewModel: ObservableObject {
    @Published var hasAnnouncement: Bool = false
    @Published var announcementData: AnnouncementData?

    private var hasCheckedAnnouncement = false
    private let announcementStateManager: AnnouncementStateManager
    private let languageManager: LanguageManager
    private let gitHubService: GitHubService

    /// Creates a view model with the required services.
    /// - Parameters:
    ///   - announcementStateManager: Manages announcement acknowledgment state.
    ///   - languageManager: Provides the selected language.
    ///   - gitHubService: Fetches announcement data from GitHub.
    init(
        announcementStateManager: AnnouncementStateManager = AppServices.announcementStateManager,
        languageManager: LanguageManager = AppServices.languageManager,
        gitHubService: GitHubService = AppServices.gitHubService,
    ) {
        self.announcementStateManager = announcementStateManager
        self.languageManager = languageManager
        self.gitHubService = gitHubService
    }

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
        if announcementStateManager.isAnnouncementAcknowledgedForCurrentVersion() {
            hasAnnouncement = false
            announcementData = nil
            return
        }

        let version = Bundle.main.appVersion
        let language = languageManager.selectedLanguage.isEmpty
            ? AppServices.languageManager.selectedLanguage
            : languageManager.selectedLanguage

        do {
            let data = try await gitHubService.fetchAnnouncement(
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
