//
//  AddOrDeleteResourceButtonViewModel+Lifecycle.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Extension providing lifecycle event handling for `AddOrDeleteResourceButtonViewModel`.
extension AddOrDeleteResourceButtonViewModel {
    func onAppear(selectedItem: SidebarItem, scannedDetailIds: Set<String>) {
        if type == false {
            addButtonState = .installed
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
        oldFileNameForUpdate = effectiveFileName
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
            if query == ResourceType.minecraftJavaServer.rawValue {
                addButtonState = .loading
                Task { await addServerToGame() }
                return
            }
            addButtonState = .loading
            Task { await loadGameResourceInstallDetailBeforeOpeningSheet() }
        case .installed, .update:
            if type == false {
                projectPendingDeletion = project
            }
        default:
            break
        }
    }

    func addServerToGame() async {
        guard let gameInfo else {
            addButtonState = .idle
            return
        }

        guard let gameRepository,
              let result = await ResourceDetailLoader.loadProjectDetail(
                  projectId: project.projectId,
                  gameRepository: gameRepository,
                  resourceType: query,
                  skipCompatibleGameResolution: true,
              )
        else {
            addButtonState = .idle
            return
        }

        do {
            try await MinecraftJavaServerResourceUtils.addServerToGameIfNeeded(
                game: gameInfo,
                detail: result.detail,
            )
            addButtonState = .installed
        } catch {
            addButtonState = .idle
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to add server: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
        }
    }

    func deleteServer(gameName: String) {
        guard let serverId = getServerId() else { return }
        Task {
            var servers = try? await DIContainer.shared.system.serverAddressService.loadServerAddresses(for: gameName)
            servers?.removeAll { $0.id == serverId }
            if let servers {
                try? await DIContainer.shared.system.serverAddressService.saveServerAddresses(servers, for: gameName)
            }
            onResourceChanged?()
        }
    }

    private func getServerId() -> String? {
        guard project.projectId.hasPrefix("server_") else { return nil }
        return String(project.projectId.dropFirst("server_".count))
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
            if type == false {
                projectPendingDeletion = project
            }
        default:
            break
        }
    }
}
