import Foundation

extension GameAdvancedSettingsViewModel {
    // MARK: - Loading

    func loadCurrentSettings() {
        guard let game = currentGame else { return }
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        let xms = game.xms == 0 ? gameSettingsManager.globalXms : game.xms
        let xmx = game.xmx == 0 ? gameSettingsManager.globalXmx : game.xmx
        memoryRange = Double(xms)...Double(xmx)
        environmentVariables = game.environmentVariables
        javaPath = game.javaPath

        let jvmArgs = game.jvmArguments.trimmingCharacters(in: .whitespacesAndNewlines)
        if jvmArgs.isEmpty {
            customJvmArguments = ""
            selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
            optimizationPreset = .balanced
            applyOptimizationPreset(.balanced)
        } else {
            customJvmArguments = parseExistingJvmArguments(jvmArgs) ? "" : jvmArgs
            if !selectedGarbageCollector.isSupported(by: currentJavaVersion) {
                selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
                applyOptimizationPreset(.balanced)
            }
        }
    }

    /// 读取当前生效 Java 路径的 `java --version` 输出
    func loadJavaVersionInfo() {
        let path = effectiveJavaPath

        guard !path.isEmpty else {
            javaVersionInfo = ""
            return
        }

        Task {
            let info = javaManager.getJavaVersionInfo(at: path) ?? ""
            await MainActor.run {
                if self.effectiveJavaPath == path {
                    self.javaVersionInfo = info
                }
            }
        }
    }
}
