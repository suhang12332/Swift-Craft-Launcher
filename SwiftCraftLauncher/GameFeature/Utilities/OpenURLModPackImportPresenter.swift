import Foundation

@MainActor
final class OpenURLModPackImportPresenter: ObservableObject {
    static let shared = OpenURLModPackImportPresenter()

    @Published var showImportSheet = false
    @Published private(set) var preselectedTempFile: URL?

    private let importViewModel = GameFormImportViewModel()

    private init() {}

    func handle(url: URL) {
        guard url.isFileURL else { return }
        guard url.pathExtension.lowercased() == "mrpack" else { return }

        Task {
            let mode = await importViewModel.prepareModPackImportMode(from: .success([url]))
            guard case let .modPackImport(file, shouldProcess) = mode else { return }

            preselectedTempFile = file
            showImportSheet = shouldProcess
        }
    }

    func clear() {
        preselectedTempFile = nil
    }
}
