//
//  FilterChip.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A chip-style button for filtering options with optional icon and custom styling.
struct FilterChip: View {
    private let label: FilterChipLabel
    let action: () -> Void

    init(
        title: String,
        isSelected: Bool = false,
        action: @escaping () -> Void = { },
        iconName: String? = nil,
        customBackgroundColor: Color? = nil,
        customBorderColor: Color? = nil,
        verticalPadding: CGFloat = 4,
        maxTextWidth: CGFloat? = nil,
        iconColor: Color? = nil,
    ) {
        label = FilterChipLabel(
            title: title,
            isSelected: isSelected,
            iconName: iconName,
            customBackgroundColor: customBackgroundColor,
            customBorderColor: customBorderColor,
            verticalPadding: verticalPadding,
            maxTextWidth: maxTextWidth,
            iconColor: iconColor,
        )
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            label.equatable()
        }
        .buttonStyle(.plain)
    }
}

/// The visual content of a chip.
///
/// Use this directly for display-only chips; wrap it in `FilterChip` when the
/// chip needs to be clickable.
struct FilterChipLabel: View, Equatable {
    let title: String
    let isSelected: Bool
    let iconName: String?
    let customBackgroundColor: Color?
    let customBorderColor: Color?
    let verticalPadding: CGFloat
    let maxTextWidth: CGFloat?
    let lineLimit: Int?
    let iconColor: Color?

    init(
        title: String,
        isSelected: Bool = false,
        iconName: String? = nil,
        customBackgroundColor: Color? = nil,
        customBorderColor: Color? = nil,
        verticalPadding: CGFloat = 4,
        maxTextWidth: CGFloat? = nil,
        lineLimit: Int? = nil,
        iconColor: Color? = nil,
    ) {
        self.title = title
        self.isSelected = isSelected
        self.iconName = iconName
        self.customBackgroundColor = customBackgroundColor
        self.customBorderColor = customBorderColor
        self.verticalPadding = verticalPadding
        self.maxTextWidth = maxTextWidth
        self.lineLimit = lineLimit
        self.iconColor = iconColor
    }

    var body: some View {
        label
            .padding(.horizontal, 8)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor),
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(borderColor, lineWidth: 1),
            )
    }

    @ViewBuilder private var label: some View {
        if let iconName {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.caption)
                    .foregroundColor(iconColor ?? (isSelected ? .white : .primary))
                text
            }
        } else {
            text
        }
    }

    private var text: some View {
        Text(title)
            .font(.subheadline)
            .lineLimit(lineLimit ?? (maxTextWidth != nil ? 1 : nil))
            .frame(maxWidth: maxTextWidth)
    }

    private var backgroundColor: Color {
        customBackgroundColor ?? (isSelected ? Color.accentColor : Color.clear)
    }

    private var borderColor: Color {
        customBorderColor ?? Color.secondary.opacity(0.2)
    }
}
