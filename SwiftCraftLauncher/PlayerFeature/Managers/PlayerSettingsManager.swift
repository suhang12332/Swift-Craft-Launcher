import Foundation
import SwiftUI

class PlayerSettingsManager: ObservableObject {
    static let shared = PlayerSettingsManager()

    @AppStorage("currentPlayerId")
    var currentPlayerId: String = "" {
        didSet { objectWillChange.send() }
    }

    /// 是否允许在启动器中使用离线登录
    @AppStorage("enableOfflineLogin")
    var enableOfflineLogin: Bool = false {
        didSet { objectWillChange.send() }
    }

    private init() {}
}
