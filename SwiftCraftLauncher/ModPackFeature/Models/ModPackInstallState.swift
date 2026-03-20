import SwiftUI

// MARK: - ModPack Install State
@MainActor
class ModPackInstallState: ObservableObject {
    @Published var isInstalling = false
    @Published var filesProgress: Double = 0
    @Published var dependenciesProgress: Double = 0
    @Published var overridesProgress: Double = 0
    @Published var currentFile: String = ""
    @Published var currentDependency: String = ""
    @Published var currentOverride: String = ""
    @Published var filesTotal: Int = 0
    @Published var dependenciesTotal: Int = 0
    @Published var overridesTotal: Int = 0
    @Published var filesCompleted: Int = 0
    @Published var dependenciesCompleted: Int = 0
    @Published var overridesCompleted: Int = 0

    func reset() {
        isInstalling = false
        filesProgress = 0
        dependenciesProgress = 0
        overridesProgress = 0
        currentFile = ""
        currentDependency = ""
        currentOverride = ""
        filesTotal = 0
        dependenciesTotal = 0
        overridesTotal = 0
        filesCompleted = 0
        dependenciesCompleted = 0
        overridesCompleted = 0
    }

    func startInstallation(
        filesTotal: Int,
        dependenciesTotal: Int,
        overridesTotal: Int = 0
    ) {
        self.filesTotal = filesTotal
        self.dependenciesTotal = dependenciesTotal
        // 只有在 overrides 还没有开始时才设置 total，避免覆盖已完成的进度
        if self.overridesTotal == 0 {
            self.overridesTotal = overridesTotal
        }
        self.isInstalling = true
        self.filesProgress = 0
        self.dependenciesProgress = 0
        // 只有在 overrides 还没有完成时才重置进度，保留已完成的 overrides 进度
        if self.overridesCompleted == 0 {
            self.overridesProgress = 0
        }
        self.filesCompleted = 0
        self.dependenciesCompleted = 0
        // 保留已完成的 overrides 进度，不重置
    }

    func updateFilesProgress(fileName: String, completed: Int, total: Int) {
        currentFile = fileName
        filesCompleted = completed
        filesTotal = total
        filesProgress = calculateProgress(completed: completed, total: total)
        objectWillChange.send()
    }

    func updateDependenciesProgress(
        dependencyName: String,
        completed: Int,
        total: Int
    ) {
        currentDependency = dependencyName
        dependenciesCompleted = completed
        dependenciesTotal = total
        dependenciesProgress = calculateProgress(
            completed: completed,
            total: total
        )
        objectWillChange.send()
    }

    func updateOverridesProgress(
        overrideName: String,
        completed: Int,
        total: Int
    ) {
        currentOverride = overrideName
        overridesCompleted = completed
        overridesTotal = total
        overridesProgress = calculateProgress(
            completed: completed,
            total: total
        )
        objectWillChange.send()
    }

    private func calculateProgress(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0.0 }
        return max(0.0, min(1.0, Double(completed) / Double(total)))
    }
}
