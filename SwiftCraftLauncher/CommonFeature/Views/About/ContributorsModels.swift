//
//  ContributorsModels.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Defines contribution types for contributors.
enum Contribution: String, CaseIterable {
    case code = "contributor.contribution.code"
    case design = "contributor.contribution.design"
    case test = "contributor.contribution.test"
    case feedback = "contributor.contribution.feedback"
    case documentation = "contributor.contribution.documentation"
    case infra = "contributor.contribution.infra"

    var localizedString: String {
        return rawValue.localized()
    }

    var color: Color {
        switch self {
        case .code: return .blue
        case .design: return .purple
        case .test: return .green
        case .feedback: return .orange
        case .documentation: return .indigo
        case .infra: return .red
        }
    }
}

/// Represents a contributor defined in static configuration.
struct StaticContributor {
    let name: String
    let url: String
    let avatar: String
    let contributions: [Contribution]
}

/// The root model for contributors data loaded from JSON.
struct ContributorsData: Codable {
    let contributors: [ContributorData]
}

struct ContributorData: Codable {
    let name: String
    let url: String
    let avatar: String
    let contributions: [String]
}
