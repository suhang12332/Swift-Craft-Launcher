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

    init() { }

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

        Task { [weak self] in
            guard let self else { return }
            do {
                var currentServers = try await DIContainer.shared.system.serverAddressService.loadServerAddresses(for: request.gameName)

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

                isSaving = false
                dismiss()
                onRefresh?()
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
        Task { [weak self] in
            guard let self else { return }
            do {
                var currentServers = try await DIContainer.shared.system.serverAddressService.loadServerAddresses(for: gameName)
                currentServers.removeAll { $0.id == serverToDelete.id }
                try await DIContainer.shared.system.serverAddressService.saveServerAddresses(currentServers, for: gameName)

                isDeleting = false
                dismiss()
                onRefresh?()
            } catch {
                isDeleting = false
                DIContainer.shared.core.errorHandler.handle(GlobalError.from(error))
            }
        }
    }
}
