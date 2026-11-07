//
//  ModrinthProjectDetailView.swift
//  ResourceFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import SwiftMarkDownUI
import SwiftUI

private enum Constants {
    static let galleryImageHeight: CGFloat = 160
    static let galleryImageMinWidth: CGFloat = 160
    static let galleryImageMaxWidth: CGFloat = 200
}

/// Displays the full project detail view with icon, title, stats, and description.
struct ModrinthProjectDetailView: View {
    let projectDetail: ModrinthProjectDetail?

    var body: some View {
        if let project = projectDetail {
            projectDetailView(project)
        } else {
            loadingView
        }
    }

    private func projectDetailView(_ project: ModrinthProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            projectHeader(project)
            projectContent(project)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private func projectHeader(_ project: ModrinthProjectDetail) -> some View {
        ModrinthProjectTitleView(projectDetail: project, style: .detail)
    }

    private func projectContent(_ project: ModrinthProjectDetail) -> some View {
        VStack(alignment: .leading) {
            descriptionView(project)
        }
        .padding(.vertical)
    }

    private func descriptionView(_ project: ModrinthProjectDetail) -> some View {
        MixedMarkdownView(project.body)
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
