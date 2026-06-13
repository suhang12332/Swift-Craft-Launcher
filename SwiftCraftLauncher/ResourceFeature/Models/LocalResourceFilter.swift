import Foundation

/// 本地资源筛选类型
enum LocalResourceFilter: String, CaseIterable, Identifiable {
    case all
    case disabled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "resource.local_filter.all".localized()
        case .disabled:
            return "resource.local_filter.disabled".localized()
        }
    }

    var icon: String {
        switch self {
        case .all:
            return "list.bullet"
        case .disabled:
            return "nosign"
        }
    }
}
