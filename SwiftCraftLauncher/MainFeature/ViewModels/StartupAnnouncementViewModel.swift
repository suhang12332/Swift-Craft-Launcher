import Foundation
import SwiftUI

@MainActor
final class StartupAnnouncementViewModel: ObservableObject {
    @Published var hasAnnouncement: Bool = false
    @Published var announcementData: AnnouncementData?

    private var hasCheckedAnnouncement = false

    func checkAnnouncementIfNeeded() async {
        guard !hasCheckedAnnouncement else { return }
        hasCheckedAnnouncement = true

        await Task(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.checkAnnouncement()
        }.value
    }

    private func checkAnnouncement() async {
        if AnnouncementStateManager.shared.isAnnouncementAcknowledgedForCurrentVersion() {
            hasAnnouncement = false
            announcementData = nil
            return
        }

        let version = Bundle.main.appVersion
        let language = LanguageManager.shared.selectedLanguage.isEmpty
            ? LanguageManager.getDefaultLanguage()
            : LanguageManager.shared.selectedLanguage

        do {
            let data = try await GitHubService.shared.fetchAnnouncement(
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
