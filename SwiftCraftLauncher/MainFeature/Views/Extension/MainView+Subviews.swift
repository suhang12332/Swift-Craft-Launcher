//
//  MainView+Subviews.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

extension MainView {
    @ViewBuilder var detailView: some View {
        if container.ui.generalSettingsManager.interfaceLayoutStyle == .classic {
            DetailView()
                .environment(container.core.favoriteStore)
                .toolbar { DetailToolbarView() }
        } else {
            ContentView()
                .toolbar { ContentToolbarView() }
                .navigationSplitViewColumnWidth(min: 235, ideal: 235, max: 280)
        }
    }

    @ViewBuilder var contentView: some View {
        if container.ui.generalSettingsManager.interfaceLayoutStyle == .classic {
            ContentView()
                .toolbar { ContentToolbarView() }
                .navigationSplitViewColumnWidth(min: 235, ideal: 235, max: 280)
        } else {
            DetailView()
                .environment(container.core.favoriteStore)
                .toolbar { DetailToolbarView() }
        }
    }
}
