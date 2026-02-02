import Foundation
import SwiftUI

class PlayerSettingsManager: ObservableObject {
    static let shared = PlayerSettingsManager()

    @AppStorage("currentPlayerId")
    var currentPlayerId: String = "" {
        didSet { objectWillChange.send() }
    }
    private init() {}
}
