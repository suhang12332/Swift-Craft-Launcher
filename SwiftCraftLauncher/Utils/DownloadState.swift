import Foundation

// MARK: - Download State
class DownloadState: ObservableObject {
    @Published var isDownloading = false
    @Published var coreProgress: Double = 0
    @Published var resourcesProgress: Double = 0
    @Published var currentCoreFile: String = ""
    @Published var currentResourceFile: String = ""
    @Published var coreTotalFiles: Int = 0
    @Published var resourcesTotalFiles: Int = 0
    @Published var coreCompletedFiles: Int = 0
    @Published var resourcesCompletedFiles: Int = 0
    @Published var isCancelled = false

    func reset() {
        isDownloading = false
        coreProgress = 0
        resourcesProgress = 0
        currentCoreFile = ""
        currentResourceFile = ""
        coreTotalFiles = 0
        resourcesTotalFiles = 0
        coreCompletedFiles = 0
        resourcesCompletedFiles = 0
        isCancelled = false
    }

    func startDownload(coreTotalFiles: Int, resourcesTotalFiles: Int) {
        self.coreTotalFiles = coreTotalFiles
        self.resourcesTotalFiles = resourcesTotalFiles
        self.isDownloading = true
        self.coreProgress = 0
        self.resourcesProgress = 0
        self.coreCompletedFiles = 0
        self.resourcesCompletedFiles = 0
        self.isCancelled = false
    }

    func cancel() {
        isCancelled = true
    }

    func updateProgress(
        fileName: String,
        completed: Int,
        total: Int,
        type: MinecraftFileManager.DownloadType
    ) {
        switch type {
        case .core:
            updateCoreProgress(fileName: fileName, completed: completed, total: total)
        case .resources:
            updateResourcesProgress(fileName: fileName, completed: completed, total: total)
        }
    }
    
    private func updateCoreProgress(fileName: String, completed: Int, total: Int) {
        currentCoreFile = fileName
        coreCompletedFiles = completed
        coreTotalFiles = total
        coreProgress = calculateProgress(completed: completed, total: total)
    }
    
    private func updateResourcesProgress(fileName: String, completed: Int, total: Int) {
        currentResourceFile = fileName
        resourcesCompletedFiles = completed
        resourcesTotalFiles = total
        resourcesProgress = calculateProgress(completed: completed, total: total)
    }
    
    private func calculateProgress(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0.0 }
        return max(0.0, min(1.0, Double(completed) / Double(total)))
    }
}

