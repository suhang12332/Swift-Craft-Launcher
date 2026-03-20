import AppKit

enum SelectionState {
    case unselected
    case some
    case all

    var controlState: NSControl.StateValue {
        switch self {
        case .unselected:
            return .off
        case .all:
            return .on
        case .some:
            return .mixed
        }
    }
}
