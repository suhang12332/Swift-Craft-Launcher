//
//  WorldInfoSectionView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

/// Displays world save files as selectable chips with detail sheet support.
import SwiftUI

struct WorldInfoSectionView: View {
    let worlds: [WorldInfo]
    let isLoading: Bool
    let gameName: String

    @State private var preparedViewModel: WorldDetailSheetViewModel?
    @State private var loadTask: Task<Void, Never>?
    @State private var currentLoadToken: UUID?

    var body: some View {
        GenericSectionView(
            title: "saveinfo.worlds",
            items: worlds,
            isLoading: isLoading,
            iconName: "folder.fill"
        ) { world in
            worldChip(for: world)
        }
        .sheet(
            isPresented: Binding(
                get: { preparedViewModel != nil },
                set: { isPresented in
                    if !isPresented {
                        preparedViewModel = nil
                    }
                }
            )
        ) {
            if let viewModel = preparedViewModel {
                WorldDetailSheetView(viewModel: viewModel)
            }
        }
    }

    private func worldChip(for world: WorldInfo) -> some View {
        FilterChip(
            title: world.name,
            action: {
                let token = UUID()
                currentLoadToken = token
                loadTask?.cancel()
                let selected = world
                loadTask = Task {
                    let viewModel = WorldDetailSheetViewModel(world: selected, gameName: gameName)
                    await viewModel.loadMetadata()
                    guard currentLoadToken == token else { return }
                    preparedViewModel = viewModel
                    currentLoadToken = nil
                }
            },
            iconName: "folder.fill",
            isLoading: false,
            maxTextWidth: 150
        )
    }
}
