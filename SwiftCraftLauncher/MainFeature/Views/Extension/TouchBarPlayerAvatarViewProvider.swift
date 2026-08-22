//
//  TouchBarPlayerAvatarViewProvider.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Supplies the app's own avatar SwiftUI view for the Touch Bar.
///
/// The view is the exact `MinecraftSkinUtils` renderer used by the in-app
/// player info UI, so the Touch Bar shows the same 3D head and loading
/// states. Instances are cached per player so SwiftUI state is preserved
/// across Touch Bar refreshes.
@MainActor
final class TouchBarPlayerAvatarViewProvider {
    static let shared = TouchBarPlayerAvatarViewProvider()

    private var cachedKey = ""
    private var cachedView: AnyView?

    private init() { }

    func view(for player: Player?) -> AnyView? {
        let key = player.map { "\($0.id)|\($0.avatarName)|\($0.isRemote)" } ?? ""
        guard key != cachedKey else { return cachedView }
        cachedKey = key
        cachedView = player.map {
            AnyView(
                MinecraftSkinUtils(
                    type: $0.isRemote ? .url : .asset,
                    src: $0.avatarName,
                    size: 28,
                ),
            )
        }
        return cachedView
    }
}
