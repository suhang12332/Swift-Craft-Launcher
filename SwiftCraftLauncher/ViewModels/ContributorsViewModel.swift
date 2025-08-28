import Foundation

@MainActor
public class ContributorsViewModel: ObservableObject {
    @Published public var contributors: [GitHubContributor] = []
    @Published public var isLoading: Bool = false

    private let gitHubService = GitHubService.shared

    public func fetchContributors() async {
        isLoading = true
        defer { isLoading = false }

        do {
            contributors = try await gitHubService.fetchContributors(
                perPage: 50
            )
        } catch {
            // 静默处理错误
        }
    }

    public func getContributorProfileURL(_ contributor: GitHubContributor)
        -> URL?
    {
        URL(string: contributor.htmlUrl)
    }

    public func formatContributions(_ count: Int) -> String {
        count >= 1000
            ? String(format: "%.1fk", Double(count) / 1000.0) : "\(count)"
    }
}

extension ContributorsViewModel {
    public var sortedContributors: [GitHubContributor] {
        contributors.sorted { $0.contributions > $1.contributions }
    }

    public var topContributors: [GitHubContributor] {
        Array(sortedContributors.prefix(3))
    }

    public var otherContributors: [GitHubContributor] {
        Array(sortedContributors.dropFirst(3))
    }
}
