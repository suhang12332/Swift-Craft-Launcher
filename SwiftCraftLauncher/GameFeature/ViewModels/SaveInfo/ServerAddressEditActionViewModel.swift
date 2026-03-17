import Foundation
import SwiftUI

@MainActor
final class ServerAddressEditActionViewModel: ObservableObject {
    @Published var isSaving: Bool = false
    @Published var isDeleting: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    struct SaveRequest: Sendable {
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

        guard !trimmedName.isEmpty && !trimmedAddress.isEmpty else {
            errorMessage = "saveinfo.server.invalid_fields".localized()
            showError = true
            return
        }

        guard !isSaving && !isDeleting else { return }
        isSaving = true

        Task { [weak self] in
            guard let self else { return }
            do {
                var currentServers = try await ServerAddressService.shared.loadServerAddresses(for: request.gameName)

                if let existingServer = request.existing {
                    let updatedServer = ServerAddress(
                        id: existingServer.id,
                        name: trimmedName,
                        address: trimmedAddress,
                        port: request.port,
                        hidden: request.hidden,
                        icon: existingServer.icon,
                        acceptTextures: request.acceptTextures
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
                        acceptTextures: request.acceptTextures
                    )
                    currentServers.append(newServer)
                }

                try await ServerAddressService.shared.saveServerAddresses(currentServers, for: request.gameName)

                self.isSaving = false
                dismiss()
                onRefresh?()
            } catch {
                self.isSaving = false
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }

    func deleteServer(
        serverToDelete: ServerAddress?,
        gameName: String,
        dismiss: @escaping () -> Void,
        onRefresh: (() -> Void)?
    ) {
        guard let serverToDelete else { return }
        guard !isSaving && !isDeleting else { return }

        isDeleting = true
        Task { [weak self] in
            guard let self else { return }
            do {
                var currentServers = try await ServerAddressService.shared.loadServerAddresses(for: gameName)
                currentServers.removeAll { $0.id == serverToDelete.id }
                try await ServerAddressService.shared.saveServerAddresses(currentServers, for: gameName)

                self.isDeleting = false
                dismiss()
                onRefresh?()
            } catch {
                self.isDeleting = false
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
}
