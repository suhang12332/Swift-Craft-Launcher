//
//  GeneralSettingsManager.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Combine
import Foundation
import SwiftUI

/// The interface layout style for the main window.
public enum InterfaceLayoutStyle: String, CaseIterable {
    case classic
    case focused

    public var localizedName: String {
        "settings.interface_style.\(rawValue)".localized()
    }
}

/// Manages general application settings including proxy, downloads, and layout preferences.
class GeneralSettingsManager: ObservableObject, WorkingPathProviding {
    /// Whether GitHub proxy is enabled.
    @AppStorage(AppConstants.UserDefaultsKeys.enableGitHubProxy)
    var enableGitHubProxy: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage(AppConstants.UserDefaultsKeys.gitProxyURL)
    var gitProxyURL: String = URLConfig.Defaults.gitProxyURL {
        didSet { objectWillChange.send() }
    }

    /// Whether to limit the height of common sheets.
    @AppStorage(AppConstants.UserDefaultsKeys.limitCommonSheetHeight)
    var limitCommonSheetHeight: Bool = false {
        didSet { objectWillChange.send() }
    }

    @AppStorage(AppConstants.UserDefaultsKeys.concurrentDownloads)
    var concurrentDownloads: Int = 64 {
        didSet {
            if concurrentDownloads < 1 {
                concurrentDownloads = 1
            }
            objectWillChange.send()
        }
    }

    /// The launcher working directory path.
    @AppStorage(AppConstants.UserDefaultsKeys.launcherWorkingDirectory)
    var launcherWorkingDirectory: String = AppPaths.launcherSupportDirectory.path {
        didSet { objectWillChange.send() }
    }

    /// The interface layout style for the main window.
    @AppStorage(AppConstants.UserDefaultsKeys.interfaceLayoutStyle)
    var interfaceLayoutStyle: InterfaceLayoutStyle = .classic {
        didSet { objectWillChange.send() }
    }

    init() { }

    /// The current working path, falling back to the default support directory when empty.
    var currentWorkingPath: String {
        launcherWorkingDirectory.isEmpty ? AppPaths.launcherSupportDirectory.path : launcherWorkingDirectory
    }

    var workingPathWillChange: AnyPublisher<Void, Never> {
        objectWillChange.map { _ in () }.eraseToAnyPublisher()
    }
}
