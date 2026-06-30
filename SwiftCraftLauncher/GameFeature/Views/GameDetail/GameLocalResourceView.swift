//
//  GameLocalResourceView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

/// A searchable list view for browsing locally installed game resources.
import SwiftUI
import AppKit

struct GameLocalResourceView: View {
    let game: GameVersionInfo
    let query: String
    let header: AnyView?
    @Binding var selectedItem: SidebarItem
    @Binding var selectedProjectId: String?
    let refreshToken: UUID
    @Binding var searchText: String
    @Binding var localFilter: LocalResourceFilter

    @StateObject private var viewModel = GameLocalResourceViewModel()

    var body: some View {
        List {
            if let header {
                header
                    .listRowSeparator(.hidden)
            }
            GameLocalResourceListContent(
                game: game,
                query: query,
                viewModel: viewModel,
                selectedItem: $selectedItem,
                selectedProjectId: $selectedProjectId,
                onResourceChanged: viewModel.refreshResources
            )
            if viewModel.isLoadingMore {
                loadingMoreIndicator
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: "search.resources".localized()
        )
        .onAppear {
            viewModel.updateContextOnRefreshToken(
                game: game,
                query: query,
                localFilter: localFilter,
                searchText: searchText
            )
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: refreshToken) { _, _ in
            viewModel.updateContextOnRefreshToken(
                game: game,
                query: query,
                localFilter: localFilter,
                searchText: searchText
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .localResourceImported)) { _ in
            viewModel.updateContextOnRefreshToken(
                game: game,
                query: query,
                localFilter: localFilter,
                searchText: searchText
            )
        }
        .onChange(of: query) { oldValue, newValue in
            if oldValue != newValue {
                searchText = ""
                viewModel.updateContextOnQueryChanged(
                    game: game,
                    query: newValue,
                    localFilter: localFilter
                )
            }
        }
        .onChange(of: searchText) { oldValue, newValue in
            if oldValue != newValue {
                viewModel.onSearchTextChanged(newValue)
            }
        }
        .onChange(of: localFilter) { _, _ in
            viewModel.updateContextOnLocalFilterChanged(
                game: game,
                query: query,
                localFilter: localFilter,
                searchText: searchText
            )
        }
        .alert(
            "error.notification.validation.title".localized(),
            isPresented: Binding(
                get: { viewModel.error != nil },
                set: { newValue in
                    if !newValue { viewModel.error = nil }
                }
            )
        ) {
            Button("common.close".localized()) {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }

    private var loadingMoreIndicator: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}
