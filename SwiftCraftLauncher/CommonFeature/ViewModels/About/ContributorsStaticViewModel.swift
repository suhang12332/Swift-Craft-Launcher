import Foundation

@MainActor
final class ContributorsStaticViewModel: ObservableObject {
    @Published var contributors: [StaticContributor] = []
    @Published var loaded: Bool = false
    @Published var loadFailed: Bool = false

    private var loadTask: Task<Void, Never>?
    private let gitHubService: GitHubService

    init(gitHubService: GitHubService) {
        self.gitHubService = gitHubService
    }

    convenience init() {
        self.init(gitHubService: .shared)
    }

    func load() {
        loaded = false
        loadFailed = false

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let contributorsData: ContributorsData = try await gitHubService.fetchStaticContributors()
                guard !Task.isCancelled else { return }
                self.contributors = contributorsData.contributors.map { contributorData in
                    StaticContributor(
                        name: contributorData.name,
                        url: contributorData.url,
                        avatar: contributorData.avatar,
                        contributions: contributorData.contributions.compactMap {
                            Contribution(rawValue: "contributor.contribution.\($0)")
                        }
                    )
                }
                self.loaded = true
                self.loadFailed = false
                Logger.shared.info(
                    "Successfully loaded",
                    self.contributors.count,
                    "contributors from GitHubService"
                )
            } catch {
                guard !Task.isCancelled else { return }
                Logger.shared.error("Failed to load contributors from GitHubService:", error)
                self.loadFailed = true
                self.loaded = false
            }
        }
    }

    func clearAllData() {
        loadTask?.cancel()
        loadTask = nil
        contributors = []
        loaded = false
        loadFailed = false
    }
}
