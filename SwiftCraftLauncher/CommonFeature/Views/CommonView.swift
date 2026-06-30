//
//  CommonView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

func errorView(_ error: GlobalError) -> some View {
    ContentUnavailableView {
        Label(error.notificationTitle, systemImage: "exclamationmark.triangle")
    } description: {
        Text(error.localizedDescription)
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

/// A view that displays descriptive text in a standard secondary style.
struct CommonDescriptionText: View {
    let text: String
    var width: CGFloat = 320

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .font(.subheadline)
            .frame(width: width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A row for configuring a directory path with choose and reset actions.
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
                .applyPointerHandIfAvailable()

                Button("common.reset".localized(), action: onReset)
                    .padding(.leading, 8)
            }
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

/// A breadcrumb-style path display with Finder-like icons.
struct PathBreadcrumbView: View {
    let path: String
    let maxVisible: Int = 3

    var body: some View {
        let components = path.split(separator: "/").map(String.init)
        let paths: [String] = {
            var result: [String] = []
            var current = path.hasPrefix("/") ? "/" : ""
            for comp in components {
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
            let icon: NSImage = {
                guard FileManager.default.fileExists(atPath: paths[idx]) else {
                    if #available(macOS 12.0, *) {
                        return NSWorkspace.shared.icon(for: .folder)
                    } else {
                        return NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(0))
                    }
                }
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
    func applyPointerHandIfAvailable() -> some View {
        if #available(macOS 15.0, *) {
            self.pointerStyle(.link)
        } else {
            self
        }
    }

    @ViewBuilder
    func `if`(
        _ condition: Bool,
        transform: (Self) -> some View
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

    func applyRestorationBehaviorDisabled() -> some Scene {
        if #available(macOS 15.0, *) {
            return self.restorationBehavior(.disabled)
        } else {
            return self
        }
    }
}

/// A help button that shows a popover on hover after a brief delay.
struct InfoIconWithPopover<Content: View>: View {
    /// The content displayed in the popover.
    let content: Content
    /// The delay in seconds before the popover appears on hover.
    let delay: Double

    @State private var isHovering = false
    @State private var showPopover = false
    @State private var hoverTask: Task<Void, Never>?

    init(
        iconSize: CGFloat = 14,
        delay: Double = 0.5,
        @ViewBuilder content: () -> Content
    ) {
        self.delay = delay
        self.content = content()
    }

    var body: some View {
        Group {
            HelpButton {
                showPopover.toggle()
            }
        }
        .onHover { hovering in
            isHovering = hovering
            hoverTask?.cancel()

            if hovering {
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
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .onDisappear {
            hoverTask?.cancel()
            showPopover = false
        }
    }
}

extension InfoIconWithPopover {
    init(
        text: String,
        delay: Double = 0.5
    ) where Content == AnyView {
        self.init(delay: delay) {
            AnyView(
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            )
        }
    }

    init(
        text: String,
        iconSize: CGFloat = 14,
        delay: Double = 0.5
    ) where Content == AnyView {
        self.init(delay: delay) {
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
