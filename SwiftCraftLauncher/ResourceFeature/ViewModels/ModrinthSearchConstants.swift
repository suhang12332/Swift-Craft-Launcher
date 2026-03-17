import SwiftUI

// MARK: - Constants
/// 定义 Modrinth 相关的常量
enum ModrinthConstants {
    // MARK: - UI Constants
    /// UI 相关的常量
    enum UIConstants {
        static let pageSize = 20
        static let iconSize: CGFloat = 48
        static let cornerRadius: CGFloat = 8
        static let tagCornerRadius: CGFloat = 6
        static let verticalPadding: CGFloat = 3
        static let tagHorizontalPadding: CGFloat = 3
        static let tagVerticalPadding: CGFloat = 1
        static let spacing: CGFloat = 3
        static let descriptionLineLimit = 1
        static let maxTags = 3
        static let contentSpacing: CGFloat = 8
    }

    // MARK: - API Constants
    /// API 相关的常量
    enum API {
        enum FacetType {
            static let projectType = "project_type"
            static let versions = "versions"
            static let categories = "categories"
            static let clientSide = "client_side"
            static let serverSide = "server_side"
            static let resolutions = "resolutions"
            static let performanceImpact = "performance_impact"
        }

        enum FacetValue {
            static let required = "required"
            static let optional = "optional"
            static let unsupported = "unsupported"
        }
    }
}

// MARK: - Filter Options
/// 过滤选项结构体，用于减少函数参数数量
struct FilterOptions {
    let resolutions: [String]
    let performanceImpact: [String]
    let loaders: [String]
}
