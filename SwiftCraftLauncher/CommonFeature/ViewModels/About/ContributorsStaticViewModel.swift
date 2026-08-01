//
//  ContributorsStaticViewModel.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages loading and display of static contributor information.
@MainActor
@Observable
final class ContributorsStaticViewModel {
    var contributors: [StaticContributor] = []
    var loaded: Bool = false
    var loadFailed: Bool = false

    private var loadTask: Task<Void, Never>?

    init() { }

    /// Loads static contributor data from the GitHub service.
    func load() {
        loaded = false
        loadFailed = false

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let contributorsData: ContributorsData = try await DIContainer.shared.system.gitHubService.fetchStaticContributors()
                guard !Task.isCancelled else { return }
                let count = contributorsData.contributors.count
                contributors = contributorsData.contributors.map { contributorData in
                    StaticContributor(
                        name: contributorData.name,
                        url: contributorData.url,
                        avatar: contributorData.avatar,
                        contributions: contributorData.contributions.compactMap {
                            Contribution(rawValue: "contributor.contribution.\($0)")
                        },
                    )
                }
                loaded = true
                loadFailed = false
                AppLog.common.info("Successfully loaded \(count) libraries from GitHubService")
            } catch {
                guard !Task.isCancelled else { return }
                AppLog.common.error("Failed to load contributors from GitHubService: \(error)")
                loadFailed = true
                loaded = false
            }
        }
    }

    /// Clears all loaded data and resets the loading state.
    func clearAllData() {
        loadTask?.cancel()
        loadTask = nil
        contributors = []
        loaded = false
        loadFailed = false
    }
}
