//
//  SettingsDirectorySettingRow.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Places the redesigned directory picker in a grouped settings row.
struct SettingsWorkingDirectoryRow: View {
    @Environment(GeneralSettingsManager.self)
    private var generalSettings
    @Bindable var viewModel: GeneralSettingsViewModel
    var gameRepository: GameRepository

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("settings.launcher_working_directory".localized()) {
                if !gameRepository.workingPathOptions.isEmpty {
                    Picker("", selection: Binding(
                        get: {
                            generalSettings.launcherWorkingDirectory.isEmpty
                                ? AppPaths.launcherSupportDirectory.path
                                : generalSettings.launcherWorkingDirectory
                        },
                        set: { generalSettings.launcherWorkingDirectory = $0 },
                    )) {
                        ForEach(gameRepository.workingPathOptions, id: \.path) { item in
                            Text(viewModel.workingPathDisplayString(for: item))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .tag(item.path)
                                .help(item.path)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 250)
                }
            }
            SettingsDirectorySettingRow(
                path: generalSettings.launcherWorkingDirectory.isEmpty ? AppPaths.launcherSupportDirectory.path : generalSettings.launcherWorkingDirectory,
                description: "settings.working_directory.description".localized(),
                onChoose: { viewModel.showDirectoryPicker = true },
                onReset: { viewModel.resetWorkingDirectorySafely() },
            )
            .fileImporter(isPresented: $viewModel.showDirectoryPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                viewModel.handleDirectoryImport(result)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            Task { await gameRepository.refreshWorkingPathOptions() }
        }
        .onChange(of: generalSettings.launcherWorkingDirectory) { _, _ in
            viewModel.onWorkingDirectoryChanged()
        }
    }
}

/// A directory row sized for grouped settings forms.
struct SettingsDirectorySettingRow: View {
    let path: String
    let description: String
    let onChoose: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SettingsPathBreadcrumbView(path: path)
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

/// A breadcrumb that omits leading segments when horizontal space is limited.
private struct SettingsPathBreadcrumbView: View {
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
