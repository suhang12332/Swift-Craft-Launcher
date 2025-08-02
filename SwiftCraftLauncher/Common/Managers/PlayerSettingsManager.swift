import Foundation
import SwiftUI

class PlayerSettingsManager: ObservableObject {
    static let shared = PlayerSettingsManager()
    
    @AppStorage("currentPlayerId") public var currentPlayerId: String = "" {
        didSet { objectWillChange.send() }
    }
    // 可扩展更多玩家相关设置
    private init() {}
}
