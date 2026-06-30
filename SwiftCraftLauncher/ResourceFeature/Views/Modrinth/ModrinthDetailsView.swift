//
//  ModrinthDetailsView.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays license, publish date, and update date for a project detail.
struct ModrinthDetailsSection: View, Equatable {
    let project: ModrinthProjectDetail?
    let isLoading: Bool

    private var publishedDateString: String? {
        project?.published.formatted(.relative(presentation: .named))
    }

    private var updatedDateString: String? {
        project?.updated.formatted(.relative(presentation: .named))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("project.info.details".localized())
                .font(.headline)
                .padding(.bottom, 4)

            if isLoading {
                CategorySectionSkeletonView(count: 3)
            } else if let project, let publishedDateString, let updatedDateString {
                VStack(alignment: .leading, spacing: 8) {
                    ModrinthDetailRow(
                        label: "project.info.details.licensed".localized(),
                        value: (project.license?.name).map { $0.isEmpty ? "Unknown" : $0 } ?? "Unknown",
                    )
                    ModrinthDetailRow(
                        label: "project.info.details.published".localized(),
                        value: publishedDateString,
                    )
                    ModrinthDetailRow(
                        label: "project.info.details.updated".localized(),
                        value: updatedDateString,
                    )
                }
            }
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.isLoading == rhs.isLoading &&
        lhs.project?.id == rhs.project?.id &&
        lhs.project?.license?.id == rhs.project?.license?.id &&
        lhs.project?.published == rhs.project?.published &&
        lhs.project?.updated == rhs.project?.updated
    }
}

/// A single detail row showing a label and value.
private struct ModrinthDetailRow: View, Equatable {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.callout.bold())
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            FilterChip(
                title: value,
                isSelected: false,
            ) { }
        }
        .frame(minHeight: 20)
    }
}
