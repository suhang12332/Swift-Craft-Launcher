//
//  ServerAddressEditActionViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation
import SwiftUI

/// View model for editing server addresses, managing save and delete operations with error handling.
@MainActor
@Observable
final class ServerAddressEditActionViewModel {
    var isSaving: Bool = false
    var isDeleting: Bool = false

    private var saveTask: Task<Void, Never>?
    private var deleteTask: Task<Void, Never>?

    init() { }

    /// Cancels in-flight save/delete work when the sheet disappears.
    func cancelInFlight() {
        saveTask?.cancel()
        saveTask = nil
        deleteTask?.cancel()
        deleteTask = nil
        isSaving = false
        isDeleting = false
    }

    struct SaveRequest {
        let existing: ServerAddress?
        let gameName: String
        let name: String
        let address: String
        let port: Int
        let hidden: Bool
        let acceptTextures: Bool
    }

    func saveServer(request: SaveRequest, dismiss: @escaping () -> Void, onRefresh: (() -> Void)?) {
        let trimmedName = request.name.trimmingCharacters(in: .whitespaces)
        let trimmedAddress = request.address.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty, !trimmedAddress.isEmpty else {
            DIContainer.shared.core.errorHandler.handle(GlobalError.validation(
                i18nKey: "saveinfo.server.invalid_fields",
                level: .silent,
            ))
            return
        }

        guard !isSaving, !isDeleting else { return }
        isSaving = true

        saveTask?.cancel()
        saveTask = Task { [weak self] in
            guard let self else { return }
            do {
                var currentServers = try await DIContainer.shared.system.serverAddressService.loadServerAddresses(for: request.gameName)

                try Task.checkCancellation()

                if let existingServer = request.existing {
                    let updatedServer = ServerAddress(
                        id: existingServer.id,
                        name: trimmedName,
                        address: trimmedAddress,
                        port: request.port,
                        hidden: request.hidden,
                        icon: existingServer.icon,
                        acceptTextures: request.acceptTextures,
                    )

                    if let index = currentServers.firstIndex(where: { $0.id == existingServer.id }) {
                        currentServers[index] = updatedServer
                    } else {
                        currentServers.append(updatedServer)
                    }
                } else {
                    let newServer = ServerAddress(
                        name: trimmedName,
                        address: trimmedAddress,
                        port: request.port,
                        hidden: request.hidden,
                        icon: nil,
                        acceptTextures: request.acceptTextures,
                    )
                    currentServers.append(newServer)
                }

                try await DIContainer.shared.system.serverAddressService.saveServerAddresses(currentServers, for: request.gameName)

                try Task.checkCancellation()

                isSaving = false
                dismiss()
                onRefresh?()
            } catch is CancellationError {
                isSaving = false
            } catch {
                isSaving = false
                DIContainer.shared.core.errorHandler.handle(GlobalError.from(error))
            }
        }
    }

    func deleteServer(
        serverToDelete: ServerAddress?,
        gameName: String,
        dismiss: @escaping () -> Void,
        onRefresh: (() -> Void)?,
    ) {
        guard let serverToDelete else { return }
        guard !isSaving, !isDeleting else { return }

        isDeleting = true
        deleteTask?.cancel()
        deleteTask = Task { [weak self] in
            guard let self else { return }
            do {
                var currentServers = try await DIContainer.shared.system.serverAddressService.loadServerAddresses(for: gameName)

                try Task.checkCancellation()

                currentServers.removeAll { $0.id == serverToDelete.id }
                try await DIContainer.shared.system.serverAddressService.saveServerAddresses(currentServers, for: gameName)

                try Task.checkCancellation()

                isDeleting = false
                dismiss()
                onRefresh?()
            } catch is CancellationError {
                isDeleting = false
            } catch {
                isDeleting = false
                DIContainer.shared.core.errorHandler.handle(GlobalError.from(error))
            }
        }
    }
}
