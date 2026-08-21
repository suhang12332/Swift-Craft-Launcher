//
//  WorldDetailNBTViews.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// A recursive tree view for displaying NBT data structures.
import SwiftNBT
import SwiftUI

struct NBTStructureView: View {
    let data: NBTCompound
    @State private var expandedKeys: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(data.keys.sorted()), id: \.self) { key in
                if let value = data[key] {
                    NBTEntryView(
                        key: key,
                        value: value,
                        expandedKeys: $expandedKeys,
                        indentLevel: 0,
                        fullKey: key,
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// A single NBT entry that renders as a disclosure group for compounds and lists, or a value row for scalars and arrays.
private struct NBTEntryView: View {
    let key: String
    let value: NBTValue
    @Binding var expandedKeys: Set<String>
    let indentLevel: Int
    let fullKey: String
    @State private var isHovered = false

    init(key: String, value: NBTValue, expandedKeys: Binding<Set<String>>, indentLevel: Int, fullKey: String? = nil) {
        self.key = key
        self.value = value
        _expandedKeys = expandedKeys
        self.indentLevel = indentLevel
        self.fullKey = fullKey ?? key
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch value {
            case let .compound(dict):
                NBTDisclosureButton(
                    isExpanded: expandedKeys.contains(fullKey),
                    label: key,
                    suffix: "{\(dict.count)}",
                    indentLevel: indentLevel,
                    isHovered: $isHovered,
                    action: toggleExpansion,
                )

                if expandedKeys.contains(fullKey) {
                    ForEach(Array(dict.keys.sorted()), id: \.self) { subKey in
                        if let subValue = dict[subKey] {
                            Self(
                                key: subKey,
                                value: subValue,
                                expandedKeys: $expandedKeys,
                                indentLevel: indentLevel + 1,
                                fullKey: "\(fullKey).\(subKey)",
                            )
                        }
                    }
                }
            case let .list(items):
                NBTDisclosureButton(
                    isExpanded: expandedKeys.contains(fullKey),
                    label: key,
                    suffix: "[\(items.count)]",
                    indentLevel: indentLevel,
                    isHovered: $isHovered,
                    action: toggleExpansion,
                )

                if expandedKeys.contains(fullKey) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        Self(
                            key: "[\(index)]",
                            value: item,
                            expandedKeys: $expandedKeys,
                            indentLevel: indentLevel + 1,
                            fullKey: "\(fullKey)[\(index)]",
                        )
                    }
                }
            case .byte, .short, .int, .long, .float, .double, .string,
                 .byteArray, .intArray, .longArray:
                NBTValueRow(
                    label: key,
                    value: value.description,
                    indentLevel: indentLevel,
                )
            }
        }
    }

    private func toggleExpansion() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedKeys.contains(fullKey) {
                expandedKeys.remove(fullKey)
            } else {
                expandedKeys.insert(fullKey)
            }
        }
    }
}

/// A disclosure button styled for macOS, used to expand or collapse NBT compound and list entries.
private struct NBTDisclosureButton: View {
    let isExpanded: Bool
    let label: String
    let suffix: String
    let indentLevel: Int
    @Binding var isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.secondary)
                    .frame(width: 14, alignment: .leading)
                    .contentShape(Rectangle())

                Text(label)
                    .font(.subheadline.monospaced())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(suffix)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .padding(.leading, CGFloat(indentLevel) * 20)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.secondary.opacity(0.1) : Color.clear),
            )
        }
        .buttonStyle(.plain)
        .applyPointerHandIfAvailable()
    }
}

/// A row displaying a label-value pair from NBT data with monospaced font.
private struct NBTValueRow: View {
    let label: String
    let value: String
    let indentLevel: Int
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Text(label + ":")
                .font(.subheadline.monospaced())
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .trailing)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(value)
                .font(.subheadline.monospaced())
                .foregroundColor(.primary)
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .padding(.leading, CGFloat(indentLevel) * 20 + 14)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.secondary.opacity(0.08) : Color.clear),
        )
        .applyPointerHandIfAvailable()
    }
}
