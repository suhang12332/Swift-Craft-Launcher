//
//  ModrinthDetailCardSkeletonView.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A skeleton placeholder for loading Modrinth list cards.
struct ModrinthDetailCardSkeletonView: View {
    var body: some View {
        ModrinthDetailCardLayout(
            icon: { ModrinthDetailCardPlaceholderIcon() },
            title: { titlePlaceholder },
            description: { descriptionPlaceholder },
            tags: { tagsPlaceholder },
            trailing: { trailingPlaceholder },
        )
        .redacted(reason: .placeholder)
    }

    private var titlePlaceholder: some View {
        HStack(spacing: 4) {
            Text(skeletonTitle)
                .font(.headline)
                .lineLimit(1)
            Text("by \(skeletonAuthor)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private var descriptionPlaceholder: some View {
        Text(skeletonDescription)
            .font(.subheadline)
            .lineLimit(ModrinthConstants.UIConstants.descriptionLineLimit)
            .foregroundColor(.secondary)
    }

    private var tagsPlaceholder: some View {
        HStack(spacing: ModrinthConstants.UIConstants.spacing) {
            ForEach(skeletonTags) { tag in
                ModrinthDetailCardTagView(text: tag.text)
            }
        }
    }

    private var trailingPlaceholder: some View {
        VStack(alignment: .trailing, spacing: ModrinthConstants.UIConstants.spacing) {
            ModrinthDetailCardInfoRowView(icon: "arrow.down.circle", text: skeletonDownloads)
            ModrinthDetailCardInfoRowView(icon: "heart", text: skeletonFollows)
            Button(action: { }, label: {
                Text("resource.add".localized())
            })
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .font(.caption2)
            .controlSize(.small)
            .disabled(true)
        }
    }
}

func placeholder(lengthRange: ClosedRange<Int>) -> String {
    String(repeating: "S", count: Int.random(in: lengthRange))
}

struct SkeletonTag: Identifiable {
    let id = UUID()
    let text: String
}

private extension ModrinthDetailCardSkeletonView {
    var skeletonDescription: String {
        placeholder(lengthRange: 50 ... 90)
        }

    var skeletonTitle: String { placeholder(lengthRange: 8 ... 18) }
    var skeletonAuthor: String { placeholder(lengthRange: 6 ... 14) }
    var skeletonFileName: String { placeholder(lengthRange: 12 ... 28) }

    var skeletonTags: [SkeletonTag] {
        [
            .init(text: placeholder(lengthRange: 6 ... 12)),
            .init(text: placeholder(lengthRange: 4 ... 10)),
            .init(text: placeholder(lengthRange: 5 ... 11)),
        ]
    }

    var skeletonDownloads: String { placeholder(lengthRange: 4 ... 8) }
    var skeletonFollows: String { placeholder(lengthRange: 3 ... 7) }
}

/// A list of skeleton rows for loading state.
struct ModrinthDetailListSkeletonRows: View {
    let count: Int

    init(
        count: Int = ModrinthConstants.UIConstants.skeletonPlaceholderCount,
    ) {
        self.count = count
    }

    var body: some View {
        ForEach(0 ..< count, id: \.self) { _ in
            ModrinthDetailCardSkeletonView()
                .padding(.vertical, ModrinthConstants.UIConstants.verticalPadding)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .listRowSeparator(.hidden)
        }
    }
}
