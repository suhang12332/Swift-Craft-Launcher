//
//  CFModrinthAdapterKitExports.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Re-exports the CFModrinthAdapterKit module and adds Sendable conformance to its types.
@_exported import CFModrinthAdapterKit

typealias Category = CFModrinthAdapterKit.Category

extension ModrinthResult: @retroactive @unchecked Sendable { }
extension ModrinthProjectDetail: @retroactive @unchecked Sendable { }
extension ModrinthProjectDetailV3: @retroactive @unchecked Sendable { }
extension ModrinthProjectDetailVersion: @retroactive @unchecked Sendable { }
extension Category: @retroactive @unchecked Sendable { }
extension GameVersion: @retroactive @unchecked Sendable { }
extension Loader: @retroactive @unchecked Sendable { }
extension CurseForgeSearchResult: @retroactive @unchecked Sendable { }
