//
//  ModPackInstallViewBuilder+App.swift
//  MainFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

extension ModPackInstallViewBuilder {
    /// The production builder that composes `ModPackFeature` into the shared game form.
    static let app = ModPackInstallViewBuilder { source, configuration in
        AnyView(
            ModPackInstallView(
                source: source,
                configuration: configuration,
            ),
        )
    }
}
