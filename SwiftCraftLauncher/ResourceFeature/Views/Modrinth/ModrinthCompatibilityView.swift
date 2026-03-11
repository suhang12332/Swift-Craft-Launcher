//
//  ModrinthCompatibilityView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//
import SwiftUI

// MARK: - Constants
private enum Constants {
    static let maxVisibleVersions = 15
    static let popoverWidth: CGFloat = 300
    static let popoverHeight: CGFloat = 400
}

// MARK: - Compatibility Section
struct ModrinthCompatibilitySection: View {
    let project: ModrinthProjectDetail?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                GameVersionsSection(versions: [], isLoading: true)
                LoadersSection(loaders: [], isLoading: true)
            } else if let project = project {
                if !project.gameVersions.isEmpty {
                    GameVersionsSection(versions: project.gameVersions, isLoading: false)
                }
                if !project.loaders.isEmpty {
                    LoadersSection(loaders: project.loaders, isLoading: false)
                }
                PlatformSupportSection(
                    clientSide: project.clientSide,
                    serverSide: project.serverSide
                )
            }
        }
    }
}

// MARK: - Game Versions Section
private struct GameVersionsSection: View {
    let versions: [String]
    let isLoading: Bool

    var body: some View {
        GenericSectionView(
            title: "project.info.versions",
            items: versions.map { IdentifiableString(id: $0) },
            isLoading: isLoading,
            maxItems: Constants.maxVisibleVersions
        ) { item in
            VersionTag(version: item.id)
        } overflowContentBuilder: { _ in
            AnyView(
                GameVersionsPopover(versions: versions)
            )
        }
    }
}

// MARK: - Game Versions Popover
private struct GameVersionsPopover: View {
    let versions: [String]

    var body: some View {
        VersionGroupedView(
            items: versions.map { FilterItem(id: $0, name: $0) },
            selectedItems: .constant([])
        ) { _ in
            // No action needed for display-only popover
        }
        .frame(width: Constants.popoverWidth, height: Constants.popoverHeight)
    }
}

// MARK: - Version Tag
private struct VersionTag: View {
    let version: String

    var body: some View {
        FilterChip(
            title: version,
            isSelected: false
        ) {}
    }
}

// MARK: - Loaders Section
private struct LoadersSection: View {
    let loaders: [String]
    let isLoading: Bool

    var body: some View {
        GenericSectionView(
            title: "project.info.platforms",
            items: loaders.map { IdentifiableString(id: $0) },
            isLoading: isLoading
        ) { item in
            VersionTag(version: item.id)
        }
    }
}

// MARK: - Platform Support Section
private struct PlatformSupportSection: View {
    let clientSide: String
    let serverSide: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\("platform.support".localized()):")
                .font(.headline)
                .padding(.bottom, SectionViewConstants.defaultHeaderBottomPadding)

            ContentWithOverflow(
                items: [
                    IdentifiablePlatformItem(id: "client", icon: "laptopcomputer", text: "platform.client.\(clientSide)".localized()),
                    IdentifiablePlatformItem(id: "server", icon: "server.rack", text: "platform.server.\(serverSide)".localized()),
                ],
                maxHeight: SectionViewConstants.defaultMaxHeight,
                verticalPadding: SectionViewConstants.defaultVerticalPadding
            ) { item in
                PlatformSupportItem(icon: item.icon, text: item.text)
            }
        }
    }
}

// MARK: - Platform Item Models
private struct IdentifiablePlatformItem: Identifiable {
    let id: String
    let icon: String
    let text: String
}

// MARK: - Platform Support Item
private struct PlatformSupportItem: View {
    let icon: String
    let text: String

    var body: some View {
        FilterChip(
            title: text,
            isSelected: false,
            action: {},
            iconName: icon,
            iconColor: .secondary
        )
    }
}
