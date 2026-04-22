import Foundation

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

                self.libraries = decodedLibraries
                self.isLoading = false
                self.loadFailed = false
                Logger.shared.info(
                    "Successfully loaded",
                    decodedLibraries.count,
                    "libraries from GitHubService"
                )
            } catch {
                guard !Task.isCancelled else { return }
                Logger.shared.error("Failed to load libraries from GitHubService:", error)
                self.loadFailed = true
                self.isLoading = false
            }
        }
    }

    func clearAllData() {
        loadTask?.cancel()
        loadTask = nil

        libraries = []
        isLoading = true
        loadFailed = false
    }
}

struct OpenSourceLibrary: Codable, Hashable, Identifiable {
    var id: String { "\(name)|\(url)" }

    let name: String
    let url: String
    let avatar: String?
    let description: String?
}
