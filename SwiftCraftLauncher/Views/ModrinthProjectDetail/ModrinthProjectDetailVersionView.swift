//
//  ModrinthProjectDetailVersionView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/3.
//

import SwiftUI

// MARK: - Constants
private enum Constants {
    static let itemsPerPage = 10
    static let maxVisibleGameVersions = 2
    static let maxVisibleLoaders = 2
    static let popoverWidth: CGFloat = 300
    static let popoverHeight: CGFloat = 400
    static let filterPopoverWidth: CGFloat = 250
    static let filterPopoverHeight: CGFloat = 500
    static let cornerRadius: CGFloat = 4
    static let tagSpacing: CGFloat = 6
    static let tagPadding: CGFloat = 6
    static let tagVerticalPadding: CGFloat = 3
}

// MARK: - View Components
private struct VersionHeader: View {
    @Binding var selectedGameVersion: String?
    @Binding var showingVersionFilter: Bool
    let availableGameVersions: [String]

    var body: some View {
        HStack {
            Text("versions.name".localized())
                .font(.headline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            GameVersionFilter(
                selectedGameVersion: $selectedGameVersion,
                showingVersionFilter: $showingVersionFilter,
                availableGameVersions: availableGameVersions
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("versions.platforms".localized())
                .font(.headline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("versions.date".localized())
                .font(.headline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("versions.downloads".localized())
                .font(.headline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("versions.operate".localized())
                .font(.headline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

private struct GameVersionFilter: View {
    @Binding var selectedGameVersion: String?
    @Binding var showingVersionFilter: Bool
    let availableGameVersions: [String]

    var body: some View {
        HStack {
            Text("versions.game_versions".localized())
                .font(.headline.bold())

            Button {
                showingVersionFilter = true
            } label: {
                HStack(spacing: 4) {
                    if let selected = selectedGameVersion {
                        Text(selected)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingVersionFilter) {
                GameVersionFilterPopover(
                    selectedGameVersion: $selectedGameVersion,
                    showingVersionFilter: $showingVersionFilter,
                    availableGameVersions: availableGameVersions
                )
            }
        }
    }
}

private struct GameVersionFilterPopover: View {
    @Binding var selectedGameVersion: String?
    @Binding var showingVersionFilter: Bool
    let availableGameVersions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("versions.game_versions".localized())
                    .font(.headline)
                Spacer()
                if selectedGameVersion != nil {
                    Button {
                        selectedGameVersion = nil
                        showingVersionFilter = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(groupedGameVersions(availableGameVersions).keys.sorted(by: versionSort), id: \.self) { majorVersion in
                        GameVersionGroup(
                            majorVersion: majorVersion,
                            versions: groupedGameVersions(availableGameVersions)[majorVersion] ?? [],
                            selectedGameVersion: $selectedGameVersion,
                            showingVersionFilter: $showingVersionFilter
                        )
                    }
                }
            }
        }
        .padding()
        .frame(width: Constants.filterPopoverWidth, height: Constants.filterPopoverHeight)
    }

    private func versionSort(_ version1: String, _ version2: String) -> Bool {
        let components1 = version1.split(separator: ".").compactMap { Int($0) }
        let components2 = version2.split(separator: ".").compactMap { Int($0) }

        for i in 0..<min(components1.count, components2.count) where components1[i] != components2[i] {
            return components1[i] > components2[i]
        }
        return components1.count > components2.count
    }
}

private struct GameVersionGroup: View {
    let majorVersion: String
    let versions: [String]
    @Binding var selectedGameVersion: String?
    @Binding var showingVersionFilter: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(majorVersion)
                .font(.headline.bold())
                .foregroundColor(.primary)

            FlowLayout(spacing: Constants.tagSpacing) {
                ForEach(versions, id: \.self) { version in
                    Button {
                        selectedGameVersion = version
                        showingVersionFilter = false
                    } label: {
                        Text(version)
                            .font(.caption)
                            .padding(.horizontal, Constants.tagPadding)
                            .padding(.vertical, Constants.tagVerticalPadding)
                            .background(
                                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                                    .fill(selectedGameVersion == version ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                            )
                            .foregroundColor(selectedGameVersion == version ? Color.accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct VersionRow: View {
    let version: ModrinthProjectDetailVersion
    @Binding var gameVersionsPopoverId: String?
    @Binding var platformsPopoverId: String?

    var body: some View {
        HStack {
            VersionNameSection(version: version)
                .frame(maxWidth: .infinity, alignment: .leading)

            GameVersionsSection(
                version: version,
                gameVersionsPopoverId: $gameVersionsPopoverId
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            PlatformsSection(
                version: version,
                platformsPopoverId: $platformsPopoverId
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(version.datePublished, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(version.downloads)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VersionActions()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .bottom
        )
    }
}

private struct VersionNameSection: View {
    let version: ModrinthProjectDetailVersion

    var body: some View {
        HStack {
            versionTypeIcon
            VStack(alignment: .leading) {
                Text(version.versionNumber)
                    .font(.headline)
                Text(version.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var versionTypeIcon: some View {
        Group {
            if version.versionType == "release" {
                Image(systemName: "r.circle")
                    .foregroundColor(.green)
                    .font(.system(size: 18))
            } else {
                Image(systemName: "b.circle")
                    .foregroundColor(.orange)
                    .font(.system(size: 18))
            }
        }
    }
}

private struct GameVersionsSection: View {
    let version: ModrinthProjectDetailVersion
    @Binding var gameVersionsPopoverId: String?

    var body: some View {
        HStack {
            FlowLayout(spacing: Constants.tagSpacing) {
                ForEach(Array(version.gameVersions.prefix(Constants.maxVisibleGameVersions)), id: \.self) { gameVersion in
                    VersionTag(text: gameVersion)
                }
            }

            if version.gameVersions.count > Constants.maxVisibleGameVersions {
                MoreVersionsButton(
                    count: version.gameVersions.count - Constants.maxVisibleGameVersions
                ) { gameVersionsPopoverId = version.id }
                .popover(isPresented: Binding(
                    get: { gameVersionsPopoverId == version.id },
                    set: { if !$0 { gameVersionsPopoverId = nil } }
                )) {
                    GameVersionsPopover(version: version)
                }
            }
        }
    }
}

private struct GameVersionsPopover: View {
    let version: ModrinthProjectDetailVersion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("versions.game_versions".localized())
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(groupedGameVersions(version.gameVersions).keys.sorted(by: >), id: \.self) { majorVersion in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(majorVersion)
                                .font(.headline.bold())
                                .foregroundColor(.secondary)

                            FlowLayout(spacing: Constants.tagSpacing) {
                                ForEach(groupedGameVersions(version.gameVersions)[majorVersion] ?? [], id: \.self) { gameVersion in
                                    VersionTag(text: gameVersion)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: Constants.popoverWidth, height: Constants.popoverHeight)
    }
}

private struct PlatformsSection: View {
    let version: ModrinthProjectDetailVersion
    @Binding var platformsPopoverId: String?

    var body: some View {
        HStack {
            FlowLayout(spacing: Constants.tagSpacing) {
                ForEach(Array(version.loaders.prefix(Constants.maxVisibleLoaders)), id: \.self) { loader in
                    VersionTag(text: loader)
                }
            }

            if version.loaders.count > Constants.maxVisibleLoaders {
                MoreVersionsButton(
                    count: version.loaders.count - Constants.maxVisibleLoaders
                ) { platformsPopoverId = version.id }
                .popover(isPresented: Binding(
                    get: { platformsPopoverId == version.id },
                    set: { if !$0 { platformsPopoverId = nil } }
                )) {
                    PlatformsPopover(version: version)
                }
            }
        }
    }
}

private struct PlatformsPopover: View {
    let version: ModrinthProjectDetailVersion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("versions.platforms".localized())
                .font(.headline)
            FlowLayout(spacing: Constants.tagSpacing) {
                ForEach(version.loaders, id: \.self) { loader in
                    VersionTag(text: loader)
                }
            }
        }
        .padding()
        .frame(width: Constants.popoverWidth)
    }
}

private struct VersionTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, Constants.tagPadding)
            .padding(.vertical, Constants.tagVerticalPadding)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(Constants.cornerRadius)
    }
}

private struct MoreVersionsButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("+\(count)")
                .font(.caption)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

private struct VersionActions: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down")
                .foregroundColor(.accentColor)
            Image(systemName: "safari")
                .foregroundColor(.accentColor)
        }
    }
}

// MARK: - Version Grouping
private func groupedGameVersions(_ versions: [String]) -> [String: [String]] {
    var groups: [String: [String]] = [:]

    for version in versions {
        let groupKey = getVersionGroupKey(version)
        if groups[groupKey] == nil {
            groups[groupKey] = []
        }
        groups[groupKey]?.append(version)
    }

    // 对每个组内的版本进行排序
    for key in groups.keys {
        groups[key]?.sort { version1, version2 in
            let v1 = version1.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            let v2 = version2.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            return v1 > v2
        }
    }

    return groups
}

private func getVersionGroupKey(_ version: String) -> String {
    // 处理快照版本 (如 23w43a)
    if version.contains("w") {
        let year = String(version.prefix(2))
        return "Snapshot \(year)"
    }

    // 处理预发布版本 (如 1.20.4-pre1)
    if version.contains("-pre") {
        let baseVersion = version.components(separatedBy: "-pre")[0]
        return getMajorVersion(from: baseVersion)
    }

    // 处理候选版本 (如 1.20.4-rc1)
    if version.contains("-rc") {
        let baseVersion = version.components(separatedBy: "-rc")[0]
        return getMajorVersion(from: baseVersion)
    }

    // 处理正式版本 (如 1.20.4)
    return getMajorVersion(from: version)
}

private func getMajorVersion(from version: String) -> String {
    let components = version.split(separator: ".")
    if components.count >= 2 {
        return "\(components[0]).\(components[1])"
    } else {
        return "Other"
    }
}

// MARK: - Main View
struct ModrinthProjectDetailVersionView: View {
    @State private var isLoadingVersions = false
    @State private var error: Error?
    @State private var allVersions: [ModrinthProjectDetailVersion] = []
    @Binding var currentPage: Int
    @Binding var versionTotal: Int
    var projectId: String

    @State private var gameVersionsPopoverId: String?
    @State private var platformsPopoverId: String?
    @State private var selectedGameVersion: String?
    @State private var showingVersionFilter = false

    private var filteredVersions: [ModrinthProjectDetailVersion] {
        allVersions
    }

    private var paginatedVersions: [ModrinthProjectDetailVersion] {
        let startIndex = (currentPage - 1) * Constants.itemsPerPage
        let endIndex = min(startIndex + Constants.itemsPerPage, filteredVersions.count)
        guard startIndex < endIndex else { return [] }
        return Array(filteredVersions[startIndex..<endIndex])
    }

    private var availableGameVersions: [String] {
        Array(Set(allVersions.flatMap { $0.gameVersions })).sorted()
    }

    var body: some View {
        LazyVStack {
            VersionHeader(
                selectedGameVersion: $selectedGameVersion,
                showingVersionFilter: $showingVersionFilter,
                availableGameVersions: availableGameVersions
            )

            ForEach(paginatedVersions) { version in
                VersionRow(
                    version: version,
                    gameVersionsPopoverId: $gameVersionsPopoverId,
                    platformsPopoverId: $platformsPopoverId
                )
            }
        }
        .task {
            await loadVersions()
        }
        .onChange(of: selectedGameVersion) { _, _ in
            Task {
                await loadVersions()
            }
        }
    }

    private func loadVersions() async {
        isLoadingVersions = true
        error = nil

        var versions = await ModrinthService.fetchProjectVersions(id: projectId)

        if let selectedVersion = selectedGameVersion {
            versions = versions.filter { $0.gameVersions.contains(selectedVersion) }
        }

        await MainActor.run {
            allVersions = versions
            versionTotal = versions.count
            currentPage = 1
        }

        isLoadingVersions = false
    }
}
