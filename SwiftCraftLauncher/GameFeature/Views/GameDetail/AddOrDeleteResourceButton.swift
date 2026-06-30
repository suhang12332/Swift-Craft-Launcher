//
//  AddOrDeleteResourceButton.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// A button that manages adding, deleting, updating, and toggling resource installation state.
import Foundation
import SwiftUI

struct AddOrDeleteResourceButton: View {
    var project: ModrinthProject
    let selectedVersions: [String]
    let selectedLoaders: [String]
    let gameInfo: GameVersionInfo?
    let query: String
    let type: Bool
    @Binding var scannedDetailIds: Set<String>
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @Binding var isResourceDisabled: Bool
    @Binding var selectedItem: SidebarItem
    var onResourceChanged: (() -> Void)?
    /// Closure invoked after the enable/disable state toggle.
    var onToggleDisableState: ((Bool) -> Void)?
    /// Closure invoked after a successful resource update with (projectId, oldFileName, newFileName, newHash).
    var onResourceUpdated: ((String, String, String, String?) -> Void)?

    @StateObject private var viewModel: AddOrDeleteResourceButtonViewModel

    init(
        project: ModrinthProject,
        selectedVersions: [String],
        selectedLoaders: [String],
        gameInfo: GameVersionInfo?,
        query: String,
        type: Bool,
        selectedItem: Binding<SidebarItem>,
        onResourceChanged: (() -> Void)? = nil,
        scannedDetailIds: Binding<Set<String>> = .constant([]),
        isResourceDisabled: Binding<Bool> = .constant(false),
        onResourceUpdated: ((String, String, String, String?) -> Void)? = nil,
        onToggleDisableState: ((Bool) -> Void)? = nil,
    ) {
        self.project = project
        self.selectedVersions = selectedVersions
        self.selectedLoaders = selectedLoaders
        self.gameInfo = gameInfo
        self.query = query
        self.type = type
        _selectedItem = selectedItem
        self.onResourceChanged = onResourceChanged
        _scannedDetailIds = scannedDetailIds
        _isResourceDisabled = isResourceDisabled
        self.onResourceUpdated = onResourceUpdated
        self.onToggleDisableState = onToggleDisableState

        _viewModel = StateObject(
            wrappedValue: AddOrDeleteResourceButtonViewModel(
                project: project,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
                gameInfo: gameInfo,
                query: query,
                type: type,
                onResourceChanged: onResourceChanged,
                onResourceUpdated: onResourceUpdated,
                onToggleDisableState: onToggleDisableState,
                setIsResourceDisabled: { isResourceDisabled.wrappedValue = $0 },
                addScannedHash: { hash in scannedDetailIds.wrappedValue.insert(hash) },
            ),
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            LocalResourceUpdateButton(
                isVisible: type == false && viewModel.addButtonState == .update && !isResourceDisabled,
                isUpdateButtonLoading: $viewModel.isUpdateButtonLoading,
                addButtonState: viewModel.addButtonState,
                onTap: viewModel.handleUpdateTap,
            )

            LocalResourceToggle(
                isVisible: type == false,
                isDisabled: $viewModel.isDisabled,
                onToggle: viewModel.toggleDisableState,
            )

            ResourcePrimaryActionButton(
                addButtonState: viewModel.addButtonState,
                type: type,
                isDisabled: viewModel.addButtonState == .loading
                    || (viewModel.addButtonState == .installed && type),
                onTap: { viewModel.handlePrimaryTap(selectedItem: selectedItem) },
                query: query,
            )
            .onAppear {
                viewModel.setDependencies(
                    gameRepository: gameRepository,
                    playerListViewModel: playerListViewModel,
                )
                viewModel.onAppear(selectedItem: selectedItem, scannedDetailIds: scannedDetailIds)
            }
            .onChange(of: scannedDetailIds) { _, _ in
                viewModel.onScannedDetailIdsChanged(
                    selectedItem: selectedItem,
                    scannedDetailIds: scannedDetailIds,
                )
            }
        }
        .modifier(
            AddOrDeleteResourceButtonOverlays(
                viewModel: viewModel,
                project: project,
                gameInfo: gameInfo,
                query: query,
                gameRepository: gameRepository,
            ),
        )
    }
}
