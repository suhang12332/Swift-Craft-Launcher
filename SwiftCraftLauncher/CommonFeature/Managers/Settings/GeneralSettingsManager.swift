//
//  GeneralSettingsManager.swift
//  CommonFeature
//
//  Manages general application settings including proxy, downloads, and layout preferences.
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
@Observable
final class GeneralSettingsManager: WorkingPathProviding {
    /// A Combine subject that fires when the working directory path changes.
    private let workingPathDidChangeSubject = PassthroughSubject<Void, Never>()

    var enableGitHubProxy: Bool = Defaults.loadBool(forKey: AppConstants.UserDefaultsKeys.enableGitHubProxy, defaultValue: true) {
        didSet { Defaults.save(enableGitHubProxy, forKey: AppConstants.UserDefaultsKeys.enableGitHubProxy) }
    }

    var gitProxyURL: String = Defaults.loadString(forKey: AppConstants.UserDefaultsKeys.gitProxyURL, defaultValue: URLConfig.Defaults.gitProxyURL) {
        didSet { Defaults.save(gitProxyURL, forKey: AppConstants.UserDefaultsKeys.gitProxyURL) }
    }

    var limitCommonSheetHeight: Bool = Defaults.loadBool(forKey: AppConstants.UserDefaultsKeys.limitCommonSheetHeight) {
        didSet { Defaults.save(limitCommonSheetHeight, forKey: AppConstants.UserDefaultsKeys.limitCommonSheetHeight) }
    }

    var concurrentDownloads: Int = Defaults.loadInt(forKey: AppConstants.UserDefaultsKeys.concurrentDownloads, defaultValue: 64) {
        didSet { Defaults.save(max(concurrentDownloads, 1), forKey: AppConstants.UserDefaultsKeys.concurrentDownloads) }
    }

    var launcherWorkingDirectory: String = Defaults.loadString(forKey: AppConstants.UserDefaultsKeys.launcherWorkingDirectory, defaultValue: AppPaths.launcherSupportDirectory.path) {
        didSet {
            Defaults.save(launcherWorkingDirectory, forKey: AppConstants.UserDefaultsKeys.launcherWorkingDirectory)
            workingPathDidChangeSubject.send()
        }
    }

    var interfaceLayoutStyle: InterfaceLayoutStyle = Defaults.loadEnum(forKey: AppConstants.UserDefaultsKeys.interfaceLayoutStyle, defaultValue: .classic) {
        didSet { Defaults.save(interfaceLayoutStyle.rawValue, forKey: AppConstants.UserDefaultsKeys.interfaceLayoutStyle) }
    }

    /// The current working path, falling back to the default support directory when empty.
    var currentWorkingPath: String {
        launcherWorkingDirectory.isEmpty ? AppPaths.launcherSupportDirectory.path : launcherWorkingDirectory
    }

    var workingPathWillChange: AnyPublisher<Void, Never> {
        workingPathDidChangeSubject.eraseToAnyPublisher()
    }
}
