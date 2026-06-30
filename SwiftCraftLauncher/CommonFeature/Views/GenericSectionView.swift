//
//  GenericSectionView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A section view that displays a collection of items as chips with overflow handling.
struct GenericSectionView<Item: Identifiable, ChipContent: View>: View {
    let title: String
    let items: [Item]
    let isLoading: Bool
    let maxItems: Int
    let iconName: String?
    let chipBuilder: (Item) -> ChipContent
    let overflowContentBuilder: (([Item]) -> AnyView)?
    let clearAction: (() -> Void)?
    let shouldShowClearButton: () -> Bool
    let isVersionSection: Bool
    let customVisibleItems: [Item]?
    let customOverflowItems: [Item]?

    @State private var showOverflowPopover = false

    init(
        title: String,
        items: [Item],
        isLoading: Bool,
        maxItems: Int = SectionViewConstants.defaultMaxItems,
        iconName: String? = nil,
        @ViewBuilder chipBuilder: @escaping (Item) -> ChipContent,
        overflowContentBuilder: (([Item]) -> AnyView)? = nil,
        clearAction: (() -> Void)? = nil,
        shouldShowClearButton: @escaping () -> Bool = { true },
        isVersionSection: Bool = false,
        customVisibleItems: [Item]? = nil,
        customOverflowItems: [Item]? = nil,
    ) {
        self.title = title
        self.items = items
        self.isLoading = isLoading
        self.maxItems = maxItems
        self.iconName = iconName
        self.chipBuilder = chipBuilder
        self.overflowContentBuilder = overflowContentBuilder
        self.clearAction = clearAction
        self.shouldShowClearButton = shouldShowClearButton
        self.isVersionSection = isVersionSection
        self.customVisibleItems = customVisibleItems
        self.customOverflowItems = customOverflowItems
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerView
            if isLoading {
                loadingPlaceholder
            } else {
                contentWithOverflow
            }
        }
    }

    @ViewBuilder private var headerView: some View {
        if !title.isEmpty {
            let overflowItems = customOverflowItems ?? items.computeVisibleAndOverflowItems(maxItems: maxItems).1

            HStack {
                Text(title.localized())
                    .font(.headline)
                Spacer()
                if !overflowItems.isEmpty {
                    OverflowButton(
                        count: overflowItems.count,
                        isPresented: $showOverflowPopover,
                    ) {
                        overflowPopoverContent(overflowItems: overflowItems)
                    }
                }
                if let clearAction, shouldShowClearButton() {
                    clearButton(action: clearAction)
                }
            }
            .padding(.bottom, SectionViewConstants.defaultHeaderBottomPadding)
        }
    }

    private var loadingPlaceholder: some View {
        CategorySectionSkeletonView(
            count: SectionViewConstants.defaultPlaceholderCount,
            iconName: iconName,
            maxHeight: SectionViewConstants.defaultMaxHeight,
            verticalPadding: SectionViewConstants.defaultVerticalPadding,
        )
    }

    private var contentWithOverflow: some View {
        let visibleItems = customVisibleItems ?? items.computeVisibleAndOverflowItems(maxItems: maxItems).0

        return ContentWithOverflow(
            items: visibleItems,
            maxHeight: SectionViewConstants.defaultMaxHeight,
            verticalPadding: SectionViewConstants.defaultVerticalPadding,
        ) { item in
            chipBuilder(item)
        }
    }

    @ViewBuilder
    private func overflowPopoverContent(overflowItems: [Item]) -> some View {
        if let customOverflowBuilder = overflowContentBuilder {
            customOverflowBuilder(overflowItems)
        } else {
            OverflowPopoverContent(
                items: overflowItems,
                maxHeight: SectionViewConstants.defaultPopoverMaxHeight,
                width: SectionViewConstants.defaultPopoverWidth,
            ) { item in
                chipBuilder(item)
            }
        }
    }

    private func clearButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .help("filter.clear".localized())
    }
}

extension GenericSectionView {
    /// Creates a section view from a configuration.
    init<Config: SectionViewConfiguration>(
        configuration: Config,
        @ViewBuilder chipBuilder: @escaping (Item) -> ChipContent,
        overflowContentBuilder: (([Item]) -> AnyView)? = nil,
        clearAction: (() -> Void)? = nil,
        shouldShowClearButton: @escaping () -> Bool = { true },
        isVersionSection: Bool = false,
    ) where Config.Item == Item {
        self.init(
            title: configuration.title,
            items: configuration.items,
            isLoading: configuration.isLoading,
            maxItems: configuration.maxItems,
            iconName: configuration.iconName,
            chipBuilder: chipBuilder,
            overflowContentBuilder: overflowContentBuilder,
            clearAction: clearAction,
            shouldShowClearButton: shouldShowClearButton,
            isVersionSection: isVersionSection,
        )
    }
}
