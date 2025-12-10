//
//  CommonView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//
import SwiftUI

func newErrorView(_ error: GlobalError) -> some View {
    ContentUnavailableView {
        Label("result.error".localized(), systemImage: "xmark.icloud")
    } description: {
        Text(error.notificationTitle)
    }
}

func emptyResultView() -> some View {
    ContentUnavailableView {
        Label(
            "result.empty".localized(),
            systemImage: "magnifyingglass"
        )
    }
}

func emptyDropBackground() -> some View {
    RoundedRectangle(cornerRadius: 12)
        .fill(Color.gray.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundColor(.secondary.opacity(0.5))
        )
}

func spacerView() -> some View {
    Spacer().frame(maxHeight: 20)
}

// 路径设置行
struct DirectorySettingRow: View {
    let title: String
    let path: String
    let description: String
    let onChoose: () -> Void
    let onReset: () -> Void

    @State private var showPopover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: onChoose) {
                    PathBreadcrumbView(path: path)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }

                Button("common.reset".localized(), action: onReset)
                    .padding(.leading, 8)
            }
            Text(description)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}
// 路径分段显示控件（Finder风格图标）
struct PathBreadcrumbView: View {
    let path: String
    let maxVisible: Int = 3  // 最多显示几段（含首尾）

    var body: some View {
        let components = path.split(separator: "/").map(String.init)
        let paths: [String] = {
            var result: [String] = []
            var current = path.hasPrefix("/") ? "/" : ""
            for comp in components {
                current += (current == "/" ? "" : "/") + comp
                result.append(current)
            }
            return result
        }()

        let count = components.count
        let showEllipsis = count > maxVisible
        let headCount = showEllipsis ? 1 : max(0, count - maxVisible)
        let tailCount = showEllipsis ? maxVisible - 1 : count
        let startTail = max(count - tailCount, headCount)

        func segmentView(idx: Int) -> some View {
            let icon = NSWorkspace.shared.icon(forFile: paths[idx])
            return HStack(spacing: 2) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .cornerRadius(3)
                Text(components[idx])
                    .font(.body)
            }
        }

        return HStack(spacing: 0) {
            // 开头
            ForEach(0..<headCount, id: \.self) { idx in
                if idx > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.primary)
                        .padding(.horizontal, 6)
                }
                segmentView(idx: idx)
            }
            // 省略号
            if showEllipsis {
                if headCount > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.primary)
                        .padding(.horizontal, 6)
                }
                Text("…")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            // 结尾
            ForEach(startTail..<count, id: \.self) { idx in
                if idx > headCount || (showEllipsis && idx == startTail) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.primary)
                        .padding(.horizontal, 6)
                }
                if idx == count - 1 {
                    segmentView(idx: idx)
                } else {
                    segmentView(idx: idx)
                }
            }
        }
    }
}

// MARK: - Extension
extension View {
    @ViewBuilder
    func applyReplaceTransition() -> some View {
        if #available(macOS 15.0, *) {
            self.contentTransition(.symbolEffect(.replace.magic(fallback: .offUp.byLayer), options: .nonRepeating))
        } else {
            self.contentTransition(.symbolEffect(.replace.offUp.byLayer, options: .nonRepeating))
        }
    }
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
extension Scene {
    func conditionalRestorationBehavior() -> some Scene {
        if #available(macOS 15.0, *) {
            return self.restorationBehavior(.disabled)
        } else {
            return self
        }
    }
}
