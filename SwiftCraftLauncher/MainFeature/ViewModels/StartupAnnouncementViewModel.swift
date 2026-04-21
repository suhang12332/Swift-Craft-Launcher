import Foundation
import SwiftUI

@MainActor
final class StartupAnnouncementViewModel: ObservableObject {
    @Published var hasAnnouncement: Bool = false
    @Published var announcementData: AnnouncementData?

    private var hasCheckedAnnouncement = false
    private let announcementStateManager: AnnouncementStateManager
    private let languageManager: LanguageManager
    private let gitHubService: GitHubService

    init(
        announcementStateManager: AnnouncementStateManager = AppServices.announcementStateManager,
        languageManager: LanguageManager = AppServices.languageManager,
        gitHubService: GitHubService = AppServices.gitHubService
    ) {
        self.announcementStateManager = announcementStateManager
        self.languageManager = languageManager
        self.gitHubService = gitHubService
    }

    func checkAnnouncementIfNeeded() async {
        guard !hasCheckedAnnouncement else { return }
        hasCheckedAnnouncement = true

        await Task(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.checkAnnouncement()
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
            ? LanguageManager.getDefaultLanguage()
            : languageManager.selectedLanguage

        do {
            let data = try await gitHubService.fetchAnnouncement(
                version: version,
                language: language
            )

            if let data = data {
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
