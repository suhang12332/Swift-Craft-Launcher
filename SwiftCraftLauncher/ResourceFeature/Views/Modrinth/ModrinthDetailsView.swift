//
//  ModrinthDetailsView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//
import SwiftUI

// MARK: - Details Section
struct ModrinthDetailsSection: View, Equatable {
    let project: ModrinthProjectDetail?
    let isLoading: Bool

    // 缓存日期格式化结果，避免每次渲染都重新计算
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
            } else if let project = project, let publishedDateString = publishedDateString, let updatedDateString = updatedDateString {
                VStack(alignment: .leading, spacing: 8) {
                    ModrinthDetailRow(
                        label: "project.info.details.licensed".localized(),
                        value: (project.license?.name).map { $0.isEmpty ? "Unknown" : $0 } ?? "Unknown"
                    )
                    ModrinthDetailRow(
                        label: "project.info.details.published".localized(),
                        value: publishedDateString
                    )
                    ModrinthDetailRow(
                        label: "project.info.details.updated".localized(),
                        value: updatedDateString
                    )
                }
            }
        }
    }

    // 实现 Equatable，避免不必要的重新渲染
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.isLoading == rhs.isLoading &&
        lhs.project?.id == rhs.project?.id &&
        lhs.project?.license?.id == rhs.project?.license?.id &&
        lhs.project?.published == rhs.project?.published &&
        lhs.project?.updated == rhs.project?.updated
    }
}

// MARK: - Detail Row
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
                isSelected: false
            ) {}
        }
        .frame(minHeight: 20) // 设置最小高度，减少布局计算
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.label == rhs.label && lhs.value == rhs.value
    }
}
