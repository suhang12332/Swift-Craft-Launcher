//
//  FavoriteButton.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A button that toggles the favorite state of a Modrinth project.
struct FavoriteButton: View {
    @Environment(FavoriteStore.self)
    private var favoriteStore
    let projectId: String
    let query: String
    @State private var isLoading: Bool = false

    private var isFavorited: Bool {
        favoriteStore.isFavorite(id: projectId, type: query)
    }

    var body: some View {
        Button {
            Task {
                await toggleFavorite()
            }
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(1.3)
                } else {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .font(.subheadline)
                        .foregroundColor(isFavorited ? .red : .secondary)
                }
            }
            .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .applyReplaceTransition()
    }

    private func toggleFavorite() async {
        isLoading = true
        defer { isLoading = false }

        if isFavorited {
            try? favoriteStore.removeFavorite(id: projectId, type: query)
        } else {
            try? favoriteStore.addFavorite(id: projectId, type: query)
        }
    }
}
