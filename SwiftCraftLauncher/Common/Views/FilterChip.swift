//
//  FilterChip.swift
//  Launcher
//
//  Created by su on 2025/5/8.
//
import SwiftUI

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    // 可选参数
    let iconName: String?
    let isLoading: Bool
    let customBackgroundColor: Color?
    let customBorderColor: Color?
    let verticalPadding: CGFloat
    let maxTextWidth: CGFloat?
    let iconColor: Color?
    
    init(
        title: String,
        isSelected: Bool = false,
        action: @escaping () -> Void = {},
        iconName: String? = nil,
        isLoading: Bool = false,
        customBackgroundColor: Color? = nil,
        customBorderColor: Color? = nil,
        verticalPadding: CGFloat = 4,
        maxTextWidth: CGFloat? = nil,
        iconColor: Color? = nil
    ) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
        self.iconName = iconName
        self.isLoading = isLoading
        self.customBackgroundColor = customBackgroundColor
        self.customBorderColor = customBorderColor
        self.verticalPadding = verticalPadding
        self.maxTextWidth = maxTextWidth
        self.iconColor = iconColor
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: iconName != nil ? 4 : 0) {
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.caption)
                        .foregroundColor(iconColor ?? (isSelected ? .white : .primary))
                }
                Text(title)
                    .font(.subheadline)
                    .lineLimit(maxTextWidth != nil ? 1 : nil)
                    .frame(maxWidth: maxTextWidth)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor)
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
    
    private var backgroundColor: Color {
        if let customBackgroundColor = customBackgroundColor {
            return customBackgroundColor
        }
        return isSelected ? Color.accentColor : Color.clear
    }
    
    private var borderColor: Color {
        if let customBorderColor = customBorderColor {
            return customBorderColor
        }
        return Color.secondary.opacity(0.2)
    }
}
