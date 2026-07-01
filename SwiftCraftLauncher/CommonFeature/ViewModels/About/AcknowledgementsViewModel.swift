//
//  AcknowledgementsViewModel.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages loading and display of open-source library acknowledgements.
@MainActor
final class AcknowledgementsViewModel: ObservableObject {
    @Published var libraries: [OpenSourceLibrary] = []
    @Published var isLoading: Bool = true
    @Published var loadFailed: Bool = false

    private var loadTask: Task<Void, Never>?
    private let gitHubService: GitHubService

    init(gitHubService: GitHubService) {
        self.gitHubService = gitHubService
    }

    convenience init() {
        self.init(gitHubService: AppServices.gitHubService)
    }

    /// Loads acknowledgement data from the GitHub service.
    func load() {
        loadTask?.cancel()

        isLoading = true
        loadFailed = false

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try Task.checkCancellation()
                let decodedLibraries: [OpenSourceLibrary] = try await gitHubService.fetchAcknowledgements()
                try Task.checkCancellation()
                guard !Task.isCancelled else { return }

                libraries = decodedLibraries
                isLoading = false
                loadFailed = false
                AppLog.common.info("Successfully loaded \(decodedLibraries.count) libraries from GitHubService")
            } catch {
                guard !Task.isCancelled else { return }
                AppLog.common.error("Failed to load libraries from GitHubService: \(error.localizedDescription)")
                loadFailed = true
                isLoading = false
            }
        }
    }

    /// Clears all loaded data and resets the loading state.
    func clearAllData() {
        loadTask?.cancel()
        loadTask = nil

        libraries = []
        isLoading = true
        loadFailed = false
    }
}

/// Represents an open-source library used in the project.
struct OpenSourceLibrary: Codable, Hashable, Identifiable {
    var id: String { "\(name)|\(url)" }

    let name: String
    let url: String
    let avatar: String?
    let description: String?
}
