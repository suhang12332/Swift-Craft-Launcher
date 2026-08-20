//
//  ModrinthProjectDetailView.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftMarkDownUI
import SwiftUI

private enum Constants {
    static let iconSize: CGFloat = 75
    static let cornerRadius: CGFloat = 8
    static let galleryImageHeight: CGFloat = 160
    static let galleryImageMinWidth: CGFloat = 160
    static let galleryImageMaxWidth: CGFloat = 200
    static let categorySpacing: CGFloat = 6
    static let categoryPadding: CGFloat = 4
    static let categoryVerticalPadding: CGFloat = 2
    static let categoryCornerRadius: CGFloat = 12
}

/// Displays the full project detail view with icon, title, stats, and description.
struct ModrinthProjectDetailView: View {
    let projectDetail: ModrinthProjectDetail?
    @Environment(TranslationManager.self)
    private var translationManager
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
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 12) {
                projectIcon(project)
                projectInfo(project)
            }
        }
    }

    @ViewBuilder
    private func projectIcon(_ project: ModrinthProjectDetail) -> some View {
        if let iconUrl = project.iconUrl, let url = URL(string: iconUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                default:
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 80, height: 80)
                }
            }
            .onDisappear {
                URLCache.shared.removeCachedResponse(for: URLRequest(url: url))
            }
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .cornerRadius(Constants.cornerRadius)
            .clipped()
        }
    }

    private func projectInfo(_ project: ModrinthProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TranslatedText(text: project.title)
                .font(.largeTitle.bold())

            TranslatedText(text: project.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)

            projectStats(project)
        }
    }

    private func projectStats(_ project: ModrinthProjectDetail) -> some View {
        HStack {
            Label("\(project.downloads)", systemImage: "arrow.down.circle")
            Label("\(project.followers)", systemImage: "star")

            FlowLayout(spacing: Constants.categorySpacing) {
                ForEach(project.categories, id: \.self) { category in
                    CategoryTag(text: category)
                }
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private func projectContent(_ project: ModrinthProjectDetail) -> some View {
        VStack(alignment: .leading) {
            descriptionView(project)
        }
        .padding(.vertical)
    }

    private func descriptionView(_ project: ModrinthProjectDetail) -> some View {
        TranslationView(text: project.body, translationManager: translationManager) { displayed in
            MixedMarkdownView(displayed)
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CategoryTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, Constants.categoryPadding)
            .padding(.vertical, Constants.categoryVerticalPadding)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(Constants.categoryCornerRadius)
    }
}
