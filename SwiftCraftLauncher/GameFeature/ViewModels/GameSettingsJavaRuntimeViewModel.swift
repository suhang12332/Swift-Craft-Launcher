//
//  GameSettingsJavaRuntimeViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// View model for the Java runtime settings view, managing installed runtime detection and Java version info.
@MainActor
final class GameSettingsJavaRuntimeViewModel: ObservableObject {

    /// The installed runtime component names, or `nil` while scanning is in progress.
    @Published private(set) var installedRuntimeComponents: [String]?
    @Published var selectedRuntimeComponent: String = ""

    @Published private(set) var javaVersionInfo: String = ""
    @Published private(set) var javaExecutablePath: String = ""

    private var loadTask: Task<Void, Never>?
    private var loadGeneration: Int = 0
    private let javaManager: JavaManager

    init(javaManager: JavaManager = AppServices.javaManager) {
        self.javaManager = javaManager
    }

    /// A description of the Java runtime details for display in an info popover.
    var javaDetailsDescription: String {
        JavaDetailsFormatting.description(
            javaExecutablePath: javaExecutablePath,
            versionOutput: javaVersionInfo
        )
    }

    func loadDetails(forRuntimeComponent component: String) {
        loadTask?.cancel()
        guard !component.isEmpty else {
            javaVersionInfo = ""
            javaExecutablePath = ""
            return
        }

        loadGeneration += 1
        let generation = loadGeneration

        let path = javaManager.getJavaExecutablePath(version: component)
        javaExecutablePath = path

        guard FileManager.default.isExecutableFile(atPath: path) else {
            javaVersionInfo = ""
            return
        }

        loadTask = Task { [weak self, javaManager] in
            guard let self else { return }
            let info = await Task.detached {
                javaManager.getJavaVersionInfo(at: path) ?? ""
            }.value
            guard generation == self.loadGeneration else { return }
            self.javaVersionInfo = info
        }
    }

    func refreshInstalledRuntimes(showScanningIndicator: Bool) {
        if showScanningIndicator {
            installedRuntimeComponents = nil
        }
        Task { [weak self, javaManager] in
            guard let self else { return }
            let list = await Task.detached(priority: .utility) {
                javaManager.listInstalledRuntimeComponents()
            }.value
            installedRuntimeComponents = list
            if list.isEmpty {
                selectedRuntimeComponent = ""
            } else if !list.contains(selectedRuntimeComponent) {
                selectedRuntimeComponent = list[0]
            }
        }
    }
}
