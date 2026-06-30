//
//  ModrinthDetailCardView.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// A layout container for a Modrinth project detail card.
struct ModrinthDetailCardLayout<Icon: View, Title: View, Description: View, Tags: View, Trailing: View>: View {
    var contentOpacity: CGFloat = 1
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let title: () -> Title
    @ViewBuilder let description: () -> Description
    @ViewBuilder let tags: () -> Tags
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: ModrinthConstants.UIConstants.contentSpacing) {
            Group {
                icon()
                VStack(alignment: .leading, spacing: ModrinthConstants.UIConstants.spacing) {
                    title()
                    description()
                    tags()
                }
            }
            .opacity(contentOpacity)
            Spacer(minLength: 8)
            trailing()
        }
        .frame(maxWidth: .infinity)
    }
}

/// A placeholder icon used when the project icon is not available.
struct ModrinthDetailCardPlaceholderIcon: View {
    var body: some View {
        Color.gray.opacity(0.2)
            .frame(
                width: ModrinthConstants.UIConstants.iconSize,
                height: ModrinthConstants.UIConstants.iconSize
            )
            .cornerRadius(ModrinthConstants.UIConstants.cornerRadius)
    }
}

/// Displays a single Modrinth project as a card in search results.
struct ModrinthDetailCardView: View {
    var project: ModrinthProject
    let selectedVersions: [String]
    let selectedLoaders: [String]
    let gameInfo: GameVersionInfo?
    let query: String
    let type: Bool  // false = local, true = server
    @Binding var selectedItem: SidebarItem
    var onResourceChanged: (() -> Void)?
    /// Callback for local resource enable/disable state changes.
    var onLocalDisableStateChanged: ((ModrinthProject, Bool) -> Void)?
    /// Update callback: updates the current item's hash and list entry without a full scan. Parameters: (projectId, oldFileName, newFileName, newHash).
    var onResourceUpdated: ((String, String, String, String?) -> Void)?
    @Binding var scannedDetailIds: Set<String> // detail IDs from the parent for fast lookup
    @State private var addButtonState: AddButtonState = .idle
    @State private var showDeleteAlert = false
    @State private var isResourceDisabled: Bool = false
    @EnvironmentObject private var gameRepository: GameRepository

    enum AddButtonState {
        case idle
        case loading
        case installed
        case update
    }

    var body: some View {
        ModrinthDetailCardLayout(
            contentOpacity: isResourceDisabled ? 0.5 : 1,
            icon: { iconView },
            title: { titleView },
            description: { descriptionView },
            tags: { tagsView },
            trailing: { infoView }
        )
        .onAppear {
            isResourceDisabled = ResourceEnableDisableManager.isDisabled(fileName: project.fileName)
        }
        .onChange(of: project.fileName) { _, newFileName in
            isResourceDisabled = ResourceEnableDisableManager.isDisabled(fileName: newFileName)
        }
    }

    private var iconView: some View {
        Group {
            if project.projectId.hasPrefix("local_") || project.projectId.hasPrefix("file_") {
                localResourceIcon
            } else if let iconUrl = project.iconUrl,
                let url = URL(string: iconUrl) {
                AsyncImage(
                    url: url,
                    transaction: Transaction(
                        animation: .easeInOut(duration: 0.2)
                    )
                ) { phase in
                    switch phase {
                    case .empty:
                        placeholderIcon
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .transition(.opacity)
                    case .failure:
                        placeholderIcon
                    @unknown default:
                        placeholderIcon
                    }
                }
                .frame(
                    width: ModrinthConstants.UIConstants.iconSize,
                    height: ModrinthConstants.UIConstants.iconSize
                )
                .cornerRadius(ModrinthConstants.UIConstants.cornerRadius)
                .clipped()
                .onDisappear {
                    URLCache.shared.removeCachedResponse(
                        for: URLRequest(url: url)
                    )
                }
            } else {
                placeholderIcon
            }
        }
    }

    private var placeholderIcon: some View {
        ModrinthDetailCardPlaceholderIcon()
    }

    private var localResourceIcon: some View {
        Image(systemName: "questionmark.circle")
            .font(.system(size: ModrinthConstants.UIConstants.iconSize * 0.6))
            .foregroundColor(.secondary)
            .frame(
                width: ModrinthConstants.UIConstants.iconSize,
                height: ModrinthConstants.UIConstants.iconSize
            )
            .background(Color.gray.opacity(0.2))
            .cornerRadius(ModrinthConstants.UIConstants.cornerRadius)
    }

    private var titleView: some View {
        HStack(spacing: 4) {
            Text(project.title)
                .font(.headline)
                .lineLimit(1)
            if type == true {
                Text("by \(project.author)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            if type == false, let fileName = project.fileName {
                Text(fileName)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var descriptionView: some View {
        Text(project.description)
            .font(.subheadline)
            .lineLimit(ModrinthConstants.UIConstants.descriptionLineLimit)
            .foregroundColor(.secondary)
    }

    private var tagsView: some View {
        HStack(spacing: ModrinthConstants.UIConstants.spacing) {
            ForEach(
                Array(
                    project.displayCategories.prefix(
                        ModrinthConstants.UIConstants.maxTags
                    )
                ),
                id: \.self
            ) { tag in
                ModrinthDetailCardTagView(text: tag)
            }
            if project.displayCategories.count > ModrinthConstants.UIConstants.maxTags {
                Text(
                    "+\(project.displayCategories.count - ModrinthConstants.UIConstants.maxTags)"
                )
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
    }

    private var infoView: some View {
        VStack(alignment: .trailing, spacing: ModrinthConstants.UIConstants.spacing) {
            downloadInfoView
            followerInfoView
            AddOrDeleteResourceButton(
                project: project,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
                gameInfo: gameInfo,
                query: query,
                type: type,
                selectedItem: $selectedItem,
                onResourceChanged: onResourceChanged,
                scannedDetailIds: $scannedDetailIds,
                isResourceDisabled: $isResourceDisabled,
                onResourceUpdated: onResourceUpdated
            ) { isDisabled in
                onLocalDisableStateChanged?(project, isDisabled)
            }
            .environmentObject(gameRepository)
        }
    }

    private var downloadInfoView: some View {
        ModrinthDetailCardInfoRowView(
            icon: "arrow.down.circle",
            text: Self.formatNumber(project.downloads)
        )
    }

    private var followerInfoView: some View {
        ModrinthDetailCardInfoRowView(
            icon: "heart",
            text: Self.formatNumber(project.follows)
        )
    }

    static func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fk", Double(num) / 1_000)
        } else {
            return "\(num)"
        }
    }
}

/// A tag chip for a Modrinth category.
struct ModrinthDetailCardTagView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, ModrinthConstants.UIConstants.tagHorizontalPadding)
            .padding(.vertical, ModrinthConstants.UIConstants.tagVerticalPadding)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(ModrinthConstants.UIConstants.tagCornerRadius)
    }
}

/// A single info row with an icon and text.
struct ModrinthDetailCardInfoRowView: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .imageScale(.small)
            Text(text)
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
}
