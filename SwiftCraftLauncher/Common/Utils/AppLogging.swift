//
//  AppLogging.swift
//  SwiftCraftLauncher
//
//  日志协议与 Environment 注入，便于测试与替换实现。
//

import Foundation
import SwiftUI

/// 应用日志协议，便于注入与 Mock
public protocol AppLogging: AnyObject {
    func logInfo(_ items: Any..., file: String, function: String, line: Int)
    func logWarning(_ items: Any..., file: String, function: String, line: Int)
    func logError(_ items: Any..., file: String, function: String, line: Int)
}

public extension AppLogging {
    func info(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line) {
        logInfo(items, file: file, function: function, line: line)
    }
    func warning(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line) {
        logWarning(items, file: file, function: function, line: line)
    }
    func error(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line) {
        logError(items, file: file, function: function, line: line)
    }
}

// MARK: - Environment Key

private struct AppLoggerKey: EnvironmentKey {
    static let defaultValue: AppLogging = Logger.shared
}

public extension EnvironmentValues {
    var appLogger: AppLogging {
        get { self[AppLoggerKey.self] }
        set { self[AppLoggerKey.self] = newValue }
    }
}
