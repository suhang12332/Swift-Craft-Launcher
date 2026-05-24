import Foundation

extension LauncherImportViewModel {
    func handleLauncherTypeChange() {
        selectedLauncherRootPath = nil
        scannedInstances = []
        selectedInstanceIDs.removeAll()
        refreshDetectedRootAndScan()
    }

    func refreshDetectedRootAndScan() {
        scanTask?.cancel()
        let launcherType = selectedLauncherType
        if launcherType == .hmcl {
            if let selectedLauncherRootPath {
                scanTask = Task {
                    await scanInstances(at: selectedLauncherRootPath)
                }
            } else {
                isScanning = false
                scannedInstances = []
                selectedInstanceIDs.removeAll()
                updateParentState()
            }
            return
        }

        isScanning = true
        updateParentState()

        scanTask = Task {
            let detectedRoot = await Task.detached(priority: .userInitiated) {
                LauncherInstallationScanner.autoDetectedRoot(for: launcherType)
            }.value

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.selectedLauncherRootPath = detectedRoot
            }

            guard let detectedRoot else {
                await MainActor.run {
                    self.scannedInstances = []
                    self.selectedInstanceIDs.removeAll()
                    self.isScanning = false
                    self.updateParentState()
                }
                return
            }

            await scanInstances(at: detectedRoot)
        }
    }

    func updateSelectedRoot(_ rootPath: URL) {
        selectedLauncherRootPath = rootPath
        scanTask?.cancel()
        scanTask = Task {
            await scanInstances(at: rootPath)
        }
    }

    func toggleSelection(for instance: ScannedLauncherInstance, isSelected: Bool) {
        hasAdjustedSelectionDuringScan = true
        if isSelected {
            selectedInstanceIDs.insert(instance.id)
        } else {
            selectedInstanceIDs.remove(instance.id)
        }
        updateParentState()
    }

    func selectAllInstances() {
        hasAdjustedSelectionDuringScan = true
        selectedInstanceIDs = Set(scannedInstances.map(\.id))
        updateParentState()
    }

    func clearSelectedInstances() {
        hasAdjustedSelectionDuringScan = true
        selectedInstanceIDs.removeAll()
        updateParentState()
    }

    func scanInstances(at rootPath: URL) async {
        let launcherType = selectedLauncherType
        isScanning = true
        hasAdjustedSelectionDuringScan = false
        scannedInstances = []
        selectedInstanceIDs.removeAll()
        updateParentState()

        var instancesByID = [String: ScannedLauncherInstance]()
        let stream: AsyncStream<ScannedLauncherInstance>
        if launcherType == .hmcl, rootPath.pathExtension.lowercased() == "jar" {
            stream = LauncherInstallationScanner.scanHMCLInstancesStream(from: rootPath)
        } else {
            stream = LauncherInstallationScanner.scanInstancesStream(
                for: launcherType,
                rootPath: rootPath
            )
        }

        for await instance in stream {
            guard !Task.isCancelled else { return }

            instancesByID[instance.id] = instance
            scannedInstances = instancesByID.values.sorted {
                $0.info.gameName.localizedCaseInsensitiveCompare($1.info.gameName) == .orderedAscending
            }
            if !hasAdjustedSelectionDuringScan {
                selectedInstanceIDs.insert(instance.id)
            }
            updateParentState()
        }

        guard !Task.isCancelled else { return }

        isScanning = false
        updateParentState()
    }
}
