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
                // 使用字符串插值而非字符串拼接
                let separator = current == "/" ? "" : "/"
                current = "\(current)\(separator)\(comp)"
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
            // 安全获取文件图标，避免 NSXPC 警告
            let icon: NSImage = {
                // 检查文件是否存在
                guard FileManager.default.fileExists(atPath: paths[idx]) else {
                    if #available(macOS 12.0, *) {
                        return NSWorkspace.shared.icon(for: .folder)
                    } else {
                        return NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(0))
                    }
                }
                // 使用 try-catch 包装，避免潜在的 NSXPC 警告
                return NSWorkspace.shared.icon(forFile: paths[idx])
            }()
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

// MARK: - 通用信息图标组件（带 Popover）
/// 一个通用的问号标记组件，鼠标悬浮时显示详细说明
struct InfoIconWithPopover<Content: View>: View {
    /// Popover 中显示的内容
    let content: Content
    /// 图标大小
    let iconSize: CGFloat
    /// 延迟显示时间（秒）
    let delay: Double

    @State private var isHovering = false
    @State private var showPopover = false
    @State private var hoverTask: Task<Void, Never>?

    init(
        iconSize: CGFloat = 14,
        delay: Double = 0.5,
        @ViewBuilder content: () -> Content
    ) {
        self.iconSize = iconSize
        self.delay = delay
        self.content = content()
    }

    var body: some View {
        Button {
            // 点击时也显示 popover
            showPopover.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: iconSize))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
            // 取消之前的任务
            hoverTask?.cancel()

            if hovering {
                // 延迟显示 popover，避免鼠标快速移动时频繁显示
                hoverTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    if !Task.isCancelled && isHovering {
                        await MainActor.run {
                            showPopover = true
                        }
                    }
                }
            } else {
                showPopover = false
            }
        }
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            content
                .padding()
                .frame(maxWidth: 400, maxHeight: .infinity)
                .fixedSize(horizontal: true, vertical: true)
        }
        .onDisappear {
            hoverTask?.cancel()
            showPopover = false
        }
    }
}

// MARK: - 便捷初始化方法（使用字符串）
extension InfoIconWithPopover {
    /// 使用字符串文本创建 InfoIconWithPopover 的便捷初始化方法
    init(
        text: String,
        iconSize: CGFloat = 14,
        delay: Double = 0.5
    ) where Content == AnyView {
        self.init(iconSize: iconSize, delay: delay) {
            AnyView(
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            )
        }
    }
}

struct HelpButton: NSViewRepresentable {
    var action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .helpButton
        button.title = ""
        button.target = context.coordinator
        button.action = #selector(Coordinator.clicked)
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator: NSObject {
        let action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func clicked() {
            action()
        }
    }
}
