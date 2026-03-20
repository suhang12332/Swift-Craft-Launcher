import Foundation
import SwiftUI

@MainActor
final class DependencySheetActionViewModel: ObservableObject {
    @Published var error: GlobalError?

    private let isDownloadingAllDependencies: Binding<Bool>
    private let isDownloadingMainResourceOnly: Binding<Bool>

    init(
        isDownloadingAllDependencies: Binding<Bool>,
        isDownloadingMainResourceOnly: Binding<Bool>
    ) {
        self.isDownloadingAllDependencies = isDownloadingAllDependencies
        self.isDownloadingMainResourceOnly = isDownloadingMainResourceOnly
    }

    func downloadMainOnly(onDownloadMainOnly: @escaping () async -> Void) {
        Task {
            isDownloadingMainResourceOnly.wrappedValue = true
            await onDownloadMainOnly()
            isDownloadingMainResourceOnly.wrappedValue = false
        }
    }

    func downloadAll(onDownloadAll: @escaping () async -> Void) {
        Task {
            isDownloadingAllDependencies.wrappedValue = true
            await onDownloadAll()
            isDownloadingAllDependencies.wrappedValue = false
        }
    }

    private func handleDownloadError(_ error: Error) {
        let globalError = GlobalError.from(error)
        Logger.shared.error("依赖下载错误: \(globalError.chineseMessage)")
        GlobalErrorHandler.shared.handle(globalError)
        self.error = globalError
    }
}
