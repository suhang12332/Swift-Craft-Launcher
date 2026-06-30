//
//  DependencySectionView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

/// Tracks the loading and selection state of resource dependencies.
import SwiftUI

struct DependencyState {
    var dependencies: [ModrinthProjectDetail] = []
    var versions: [String: [ModrinthProjectDetailVersion]] = [:]
    var selected: [String: ModrinthProjectDetailVersion?] = [:]
    var isLoading = false
}

/// Displays a list of dependency version pickers for a resource.
struct DependencySectionView: View {
    @Binding var state: DependencyState

    var body: some View {
        if state.isLoading {
            ProgressView().controlSize(.small)
        } else if !state.dependencies.isEmpty {
            spacerView()
            VStack(alignment: .leading, spacing: 12) {
                ForEach(state.dependencies, id: \.id) { dep in
                    VStack {
                        Text(dep.title)
                            .font(.headline)
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let versions = state.versions[dep.id],
                            !versions.isEmpty {
                            CommonMenuPicker(
                                selection:
                                    Binding(
                                    get: {
                                        state.selected[dep.id] ?? versions.first
                                    },
                                    set: { state.selected[dep.id] = $0 }
                                )
                            ) {
                                Text("global_resource.dependency_version".localized())
                            } content: {
                                ForEach(versions, id: \.id) { v in
                                    Text(v.name).tag(Optional(v))
                                }
                            }
                        } else {
                            Text("global_resource.no_version".localized())
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}
