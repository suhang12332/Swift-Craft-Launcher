//
//  AppLogging.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// A protocol for logging messages at various levels.
public protocol AppLogging: AnyObject {
    func logDebug(_ items: Any..., file: String, function: String, line: Int)
    func logInfo(_ items: Any..., file: String, function: String, line: Int)
    func logWarning(_ items: Any..., file: String, function: String, line: Int)
    func logError(_ items: Any..., file: String, function: String, line: Int)
}

public extension AppLogging {
    func debug(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line) {
        logDebug(items, file: file, function: function, line: line)
    }
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

private struct AppLoggerKey: EnvironmentKey {
    static let defaultValue: AppLogging = Logger.shared
}

public extension EnvironmentValues {
    var appLogger: AppLogging {
        get { self[AppLoggerKey.self] }
        set { self[AppLoggerKey.self] = newValue }
    }
}
