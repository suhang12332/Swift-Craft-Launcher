//
//  WorldDetailNBTViews.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

/// A recursive tree view for displaying NBT data structures.
import SwiftUI

struct NBTStructureView: View {
    let data: [String: Any]
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
                        fullKey: key
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// A single NBT entry that renders as a disclosure group for compounds and arrays, or a value row for primitives.
struct NBTEntryView: View {
    let key: String
    let value: Any
    @Binding var expandedKeys: Set<String>
    let indentLevel: Int
    let fullKey: String
    @State private var isHovered = false

    init(key: String, value: Any, expandedKeys: Binding<Set<String>>, indentLevel: Int, fullKey: String? = nil) {
        self.key = key
        self.value = value
        self._expandedKeys = expandedKeys
        self.indentLevel = indentLevel
        self.fullKey = fullKey ?? key
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let dict = value as? [String: Any] {
                NBTDisclosureButton(
                    isExpanded: expandedKeys.contains(fullKey),
                    label: key,
                    suffix: "{\(dict.count)}",
                    indentLevel: indentLevel,
                    isHovered: $isHovered
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedKeys.contains(fullKey) {
                            expandedKeys.remove(fullKey)
                        } else {
                            expandedKeys.insert(fullKey)
                        }
                    }
                }

                if expandedKeys.contains(fullKey) {
                    ForEach(Array(dict.keys.sorted()), id: \.self) { subKey in
                        if let subValue = dict[subKey] {
                            Self(
                                key: subKey,
                                value: subValue,
                                expandedKeys: $expandedKeys,
                                indentLevel: indentLevel + 1,
                                fullKey: "\(fullKey).\(subKey)"
                            )
                        }
                    }
                }
            } else if let array = value as? [Any] {
                NBTDisclosureButton(
                    isExpanded: expandedKeys.contains(fullKey),
                    label: key,
                    suffix: "[\(array.count)]",
                    indentLevel: indentLevel,
                    isHovered: $isHovered
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedKeys.contains(fullKey) {
                            expandedKeys.remove(fullKey)
                        } else {
                            expandedKeys.insert(fullKey)
                        }
                    }
                }

                if expandedKeys.contains(fullKey) {
                    ForEach(Array(array.enumerated()), id: \.offset) { index, item in
                        let arrayItemKey = "\(fullKey)[\(index)]"
                        if let itemDict = item as? [String: Any] {
                            Self(
                                key: "[\(index)]",
                                value: itemDict,
                                expandedKeys: $expandedKeys,
                                indentLevel: indentLevel + 1,
                                fullKey: arrayItemKey
                            )
                        } else {
                            NBTValueRow(
                                label: "[\(index)]",
                                value: formatNBTValue(item),
                                indentLevel: indentLevel + 1
                            )
                        }
                    }
                }
            } else {
                NBTValueRow(
                    label: key,
                    value: formatNBTValue(value),
                    indentLevel: indentLevel
                )
            }
        }
    }

    private func formatNBTValue(_ value: Any) -> String {
        if let v = value as? String { return "\"\(v)\"" }
        if let v = value as? Bool { return v ? "true" : "false" }
        if let v = value as? Int8 { return "\(v)b" }
        if let v = value as? Int16 { return "\(v)s" }
        if let v = value as? Int32 { return "\(v)" }
        if let v = value as? Int64 { return "\(v)L" }
        if let v = value as? Int { return "\(v)" }
        if let v = value as? Double { return "\(v)d" }
        if let v = value as? Float { return "\(v)f" }
        if let v = value as? Data { return "Data(\(v.count) bytes)" }
        if let v = value as? URL { return v.path }
        return String(describing: value)
    }
}

/// A disclosure button styled for macOS, used to expand or collapse NBT compound and array entries.
struct NBTDisclosureButton: View {
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
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 14, alignment: .leading)
                    .contentShape(Rectangle())

                Text(label)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(suffix)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .padding(.leading, CGFloat(indentLevel) * 20)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .applyPointerHandIfAvailable()
    }
}

/// A row displaying a label-value pair from NBT data with monospaced font.
struct NBTValueRow: View {
    let label: String
    let value: String
    let indentLevel: Int
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Text(label + ":")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .trailing)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .padding(.leading, CGFloat(indentLevel) * 20 + 14)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.secondary.opacity(0.08) : Color.clear)
        )
        .applyPointerHandIfAvailable()
    }
}
