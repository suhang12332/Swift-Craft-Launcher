//
//  WindowID.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/27.
//

import CoreGraphics
import SwiftUI

enum AppWindowID: String {
    case main = "main"
}

enum AuxiliaryWindowID: String, Identifiable, Hashable, Codable, CaseIterable {
    case contributors = "contributors"
    case acknowledgements = "acknowledgements"
    case aiChat = "aiChat"
    case javaDownload = "javaDownload"
    case skinPreview = "skinPreview"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .contributors:
            "about.contributors".localized()
        case .acknowledgements:
            "about.acknowledgements".localized()
        case .aiChat:
            "ai.assistant.title".localized()
        case .javaDownload:
            "global_resource.download".localized()
        case .skinPreview:
            "skin.preview".localized()
        }
    }

    var defaultSize: CGSize {
        switch self {
        case .contributors, .acknowledgements:
            CGSize(width: 280, height: 600)
        case .aiChat:
            CGSize(width: 500, height: 600)
        case .javaDownload:
            CGSize(width: 400, height: 100)
        case .skinPreview:
            CGSize(width: 1200, height: 800)
        }
    }
}
