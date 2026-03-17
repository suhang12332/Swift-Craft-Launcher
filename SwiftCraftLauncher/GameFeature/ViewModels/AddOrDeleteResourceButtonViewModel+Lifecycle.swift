import Foundation

extension AddOrDeleteResourceButtonViewModel {
    func onAppear(selectedItem: SidebarItem, scannedDetailIds: Set<String>) {
        if type == false {
            addButtonState = .installed
            if currentFileName == nil {
                currentFileName = project.fileName
            }
            updateDisableState()
            checkForUpdate()
        } else {
            updateButtonState(selectedItem: selectedItem, scannedDetailIds: scannedDetailIds)
        }
    }

    func onScannedDetailIdsChanged(selectedItem: SidebarItem, scannedDetailIds: Set<String>) {
        guard type else { return }
        updateButtonState(selectedItem: selectedItem, scannedDetailIds: scannedDetailIds)
    }

    func handleUpdateTap() {
        guard type == false else { return }
        oldFileNameForUpdate = currentFileName ?? project.fileName
        isUpdateButtonLoading = true
        Task { await loadGameResourceInstallDetailBeforeOpeningSheet() }
    }

    func handlePrimaryTap(selectedItem: SidebarItem) {
        if case .game = selectedItem {
            handlePrimaryTapInGame()
        } else if case .resource = selectedItem {
            handlePrimaryTapInResource()
        }
    }

    func handlePrimaryTapInGame() {
        switch addButtonState {
        case .idle:
            if query == ResourceType.modpack.rawValue {
                addButtonState = .loading
                Task { await loadModPackDetailBeforeOpeningSheet() }
                return
            }
            addButtonState = .loading
            Task { await loadGameResourceInstallDetailBeforeOpeningSheet() }
        case .installed, .update:
            if type == false { showDeleteAlert = true }
        default:
            break
        }
    }

    func handlePrimaryTapInResource() {
        switch addButtonState {
        case .idle:
            if type {
                if query == ResourceType.modpack.rawValue {
                    if playerListViewModel?.currentPlayer == nil {
                        activeAlert = .noPlayer
                        return
                    }
                    addButtonState = .loading
                    Task { await loadModPackDetailBeforeOpeningSheet() }
                    return
                }

                if gameRepository?.games.isEmpty ?? true {
                    activeAlert = .noGame
                    return
                }
            } else {
                if query == ResourceType.modpack.rawValue {
                    addButtonState = .loading
                    Task { await loadModPackDetailBeforeOpeningSheet() }
                    return
                }
            }

            addButtonState = .loading
            Task { await loadProjectDetailBeforeOpeningSheet() }
        case .installed, .update:
            if type == false { showDeleteAlert = true }
        default:
            break
        }
    }
}