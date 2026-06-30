//
//  ModrinthLinksView.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI
import AppKit

/// Displays project resource links (issues, source, wiki, discord).
struct ModrinthLinksSection: View {
    let project: ModrinthProjectDetail?
    let isLoading: Bool

    var body: some View {
        let links: [(String, String)] = {
            guard let project = project else { return [] }
            return [
                (project.issuesUrl, "project.info.links.issues".localized()),
                (project.sourceUrl, "project.info.links.source".localized()),
                (project.wikiUrl, "project.info.links.wiki".localized()),
                (project.discordUrl, "project.info.links.discord".localized()),
            ].compactMap { url, text in
                url.map { (text, $0) }
            }
        }()

        if isLoading || !links.isEmpty {
            GenericSectionView(
                title: "project.info.links",
                items: links.map { IdentifiableLink(id: $0.0, text: $0.0, url: $0.1) },
                isLoading: isLoading
            ) { item in
                ProjectLink(text: item.text, url: item.url)
            }
        }
    }
}

/// An identifiable link item.
private struct IdentifiableLink: Identifiable {
    let id: String
    let text: String
    let url: String
}

/// A clickable project link chip.
private struct ProjectLink: View {
    let text: String
    let url: String

    var body: some View {
        if let url = URL(string: url) {
            FilterChip(
                title: text,
                isSelected: false
            ) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
