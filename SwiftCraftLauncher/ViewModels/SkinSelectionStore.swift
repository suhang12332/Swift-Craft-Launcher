import Foundation
import SwiftUI

class SkinSelectionStore: ObservableObject {
    @Published var selectedPlayerId: String?

    func select(_ id: String?) {
        if selectedPlayerId != id { selectedPlayerId = id }
    }
}
