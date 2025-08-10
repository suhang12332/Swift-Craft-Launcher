import Foundation
import SwiftUI

public enum ThemeMode: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    public var localizedName: String {
        "settings.theme.\(rawValue)".localized()
    }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
}

class GeneralSettingsManager: ObservableObject {
    static let shared = GeneralSettingsManager()
    
    @AppStorage("themeMode") public var themeMode: ThemeMode = .system {
        didSet { objectWillChange.send() }
    }
    // 新增：启动器工作目录
    @AppStorage("launcherWorkingDirectory") public var launcherWorkingDirectory: String = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? "" {
        didSet { objectWillChange.send() }
    }
    
}
