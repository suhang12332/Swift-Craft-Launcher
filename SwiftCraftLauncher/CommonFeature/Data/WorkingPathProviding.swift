//
//  WorkingPathProviding.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Combine
import Foundation

/// Provides a configurable working directory for the launcher.
public protocol WorkingPathProviding: AnyObject {
    /// The active working directory path. Returns an empty string when using the default.
    var currentWorkingPath: String { get }
    /// Publishes before the working directory changes.
    var workingPathWillChange: AnyPublisher<Void, Never> { get }
}
