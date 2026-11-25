//
//  ModPackInstallViewBuilder.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Builds the mod pack installation view shown by the shared game form.
///
/// The builder is injected by the app shell (`MainFeature`) so `GameFeature`
/// never depends on `ModPackFeature`.
struct ModPackInstallViewBuilder: @unchecked Sendable {
    typealias Build = @MainActor (ModPackInstallSource, GameFormConfiguration) -> AnyView

    private let build: Build

    init(build: @escaping Build) {
        self.build = build
    }

    @MainActor
    func makeView(source: ModPackInstallSource, configuration: GameFormConfiguration) -> AnyView {
        build(source, configuration)
    }
}

extension EnvironmentValues {
    // The injected builder for the mod pack installation view, or `nil` when unavailable.
    @Entry var modPackInstallViewBuilder: ModPackInstallViewBuilder?
}
