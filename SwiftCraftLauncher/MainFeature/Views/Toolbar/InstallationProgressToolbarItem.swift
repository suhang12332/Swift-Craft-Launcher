//
//  InstallationProgressToolbarItem.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays active hidden installation tasks in the main window toolbar.
struct InstallationProgressToolbarItem: ToolbarContent {
    @State private var taskManager = InstallationTaskManager.shared

    var body: some ToolbarContent {
        if !taskManager.progress.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(sortedProgress) { item in
                        VStack(alignment: .leading) {
                            Text(item.title)
                            if let fraction = item.fraction {
                                Text(String(format: "%.0f%%", fraction * 100))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("common.loading".localized())
                                    .foregroundStyle(.secondary)
                            }
                            if !item.currentFile.isEmpty {
                                Text(item.currentFile)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Button("common.stop".localized()) {
                            taskManager.cancel(item.id)
                        }
                    }
                } label: {
                    if let item = sortedProgress.first {
                        ProgressView(value: item.fraction)
                            .frame(width: 18)
                        if let fraction = item.fraction {
                            Text(String(format: "%.0f%%", fraction * 100))
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .help("common.loading".localized())
            }
        }
    }

    private var sortedProgress: [InstallationProgress] {
        taskManager.progress.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}
