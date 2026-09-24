//
//  CommonView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

@MainActor
func errorView(_ error: GlobalError) -> some View {
    ContentUnavailableView {
        Label(error.notificationTitle, systemImage: "exclamationmark.triangle")
    } description: {
        Text(error.localizedDescription)
    }
}

@MainActor
func emptyDropBackground() -> some View {
    RoundedRectangle(cornerRadius: 12)
        .fill(Color.gray.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundColor(.secondary.opacity(0.5)),
        )
}

@MainActor
func spacerView() -> some View {
    Spacer().frame(height: 20)
}

/// A view that displays descriptive text in a standard secondary style.
struct CommonDescriptionText: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func settingsDescription(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            self
            CommonDescriptionText(text: text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A row for configuring a directory path with choose and reset actions.
struct DirectorySettingRow: View {
    let path: String
    let description: String
    let onChoose: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                PathBreadcrumbView(path: path)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(path)

                Button("common.browse".localized(), action: onChoose)
                Button("common.reset".localized(), action: onReset)
            }
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A breadcrumb-style path display with Finder-like icons.
struct PathBreadcrumbView: View {
    let path: String

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

        func segmentView(idx: Int) -> some View {
            let icon: NSImage = {
                guard FileManager.default.fileExists(atPath: paths[idx]) else {
                    return NSWorkspace.shared.icon(for: .folder)
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

        func breadcrumb(startIndex: Int) -> some View {
            HStack(spacing: 0) {
                if startIndex > 0 {
                    Text("…")
                        .font(.body)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .bold()
                        .padding(.horizontal, 6)
                }
                ForEach(startIndex ..< components.count, id: \.self) { idx in
                    if idx > startIndex {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .bold()
                            .padding(.horizontal, 6)
                    }
                    segmentView(idx: idx)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }

        return ViewThatFits(in: .horizontal) {
            breadcrumb(startIndex: 0)
            breadcrumb(startIndex: max(0, components.count - 2))
            breadcrumb(startIndex: max(0, components.count - 1))
            Text(components.last ?? "/")
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(path)
    }
}

extension View {
    @ViewBuilder
    func applyReplaceTransition() -> some View {
        if #available(macOS 15.0, *) {
            contentTransition(.symbolEffect(.replace.magic(fallback: .offUp.byLayer), options: .nonRepeating))
        } else {
            contentTransition(.symbolEffect(.replace.offUp.byLayer, options: .nonRepeating))
        }
    }

    @ViewBuilder
    func applyPointerHandIfAvailable() -> some View {
        if #available(macOS 15.0, *) {
            pointerStyle(.link)
        } else {
            self
        }
    }

    @ViewBuilder
    func `if`(
        _ condition: Bool,
        transform: (Self) -> some View,
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

extension Scene {
    func applyRestorationBehaviorDisabled() -> some Scene {
        if #available(macOS 15.0, *) {
            return restorationBehavior(.disabled)
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

    init(
        iconSize _: CGFloat = 14,
        delay: Double = 0.5,
        @ViewBuilder content: () -> Content,
    ) {
        self.delay = delay
        self.content = content()
    }

    var body: some View {
        HelpButton { }
            .hoverPopover(delay: delay, arrowEdge: .trailing) {
                ScrollView {
                    content
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
    }
}

extension InfoIconWithPopover {
    init(
        text: String,
        delay: Double = 0.5,
    ) where Content == AnyView {
        self.init(delay: delay) {
            AnyView(
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading),
            )
        }
    }

    init(
        text: String,
        iconSize _: CGFloat = 14,
        delay: Double = 0.5,
    ) where Content == AnyView {
        self.init(delay: delay) {
            AnyView(
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading),
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

    func updateNSView(_: NSButton, context _: Context) { }

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
