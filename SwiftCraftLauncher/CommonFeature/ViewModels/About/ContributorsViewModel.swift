//
//  ContributorsViewModel.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages fetching and displaying GitHub contributors.
@MainActor
public class ContributorsViewModel: ObservableObject {
    @Published public var contributors: [GitHubContributor] = []
    @Published public var isLoading: Bool = false

    init() { }

    /// Fetches contributors from GitHub.
    public func fetchContributors() async {
        isLoading = true
        defer { isLoading = false }

        do {
            contributors = try await DIContainer.shared.system.gitHubService.fetchContributors()
        } catch { }
    }

    /// Returns the profile URL for a contributor.
    public func getContributorProfileURL(
        _ contributor: GitHubContributor,
    ) -> URL? {
        URL(string: contributor.htmlUrl)
    }

    /// Formats a contribution count for display.
    public func formatContributions(_ count: Int) -> String {
        count >= 1000
            ? String(format: "%.1fk", Double(count) / 1000.0) : "\(count)"
    }

    /// Clears the contributors list.
    public func clearContributors() {
        contributors = []
    }
}

public extension ContributorsViewModel {
    /// Contributors sorted by contribution count in descending order.
    var sortedContributors: [GitHubContributor] {
        contributors.sorted { $0.contributions > $1.contributions }
    }

    /// The top three contributors by contribution count.
    var topContributors: [GitHubContributor] {
        Array(sortedContributors.prefix(3))
    }

    /// Contributors beyond the top three.
    var otherContributors: [GitHubContributor] {
        Array(sortedContributors.dropFirst(3))
    }
}
