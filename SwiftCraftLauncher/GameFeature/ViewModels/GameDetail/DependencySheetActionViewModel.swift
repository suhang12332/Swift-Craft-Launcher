import Foundation
import SwiftUI

@MainActor
final class DependencySheetActionViewModel: ObservableObject {
    @Published var error: GlobalError?

    private let isDownloadingAllDependencies: Binding<Bool>
    private let isDownloadingMainResourceOnly: Binding<Bool>
    private let errorHandler: GlobalErrorHandler

    init(
        isDownloadingAllDependencies: Binding<Bool>,
        isDownloadingMainResourceOnly: Binding<Bool>,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler
    ) {
        self.isDownloadingAllDependencies = isDownloadingAllDependencies
        self.isDownloadingMainResourceOnly = isDownloadingMainResourceOnly
        self.errorHandler = errorHandler
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
        errorHandler.handle(globalError)
        self.error = globalError
    }
}
