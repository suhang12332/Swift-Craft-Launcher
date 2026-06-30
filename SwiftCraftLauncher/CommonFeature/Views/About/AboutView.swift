//
//  AboutView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays the application's about information including version and credits.
public struct AboutView: View {
    @State private var showingAcknowledgements: Bool

    public init(showingAcknowledgements: Bool = true) {
        self._showingAcknowledgements = State(initialValue: showingAcknowledgements)
    }

    private var appName: String { Bundle.main.appName }
    private var appVersion: String { Bundle.main.appVersion }
    private var buildNumber: String { Bundle.main.buildNumber }
    private var copyright: String { Bundle.main.copyright }

    public var body: some View {
        VStack(spacing: 12) {
            headerSection
            contentSection
            footerSection
        }
        .padding(.vertical, 16)
        .frame(width: 280, height: 600)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            appIconView
            titleSection
        }
    }

    private var footerSection: some View {
        VStack(spacing: 4) {
            Text(copyright)
                .foregroundColor(.primary)
                .font(.system(size: 10))
        }
    }

    private var appIconView: some View {
        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
            .resizable()
            .frame(width: 64, height: 64)
    }

    private var titleSection: some View {
        VStack(spacing: 4) {
            Text(appName)
                .font(.system(size: 14, weight: .bold))
                .multilineTextAlignment(.center)

            Text(String(format: "about.version.format".localized(), appVersion, buildNumber))
                .foregroundColor(.primary)
                .font(.system(size: 10))
        }
    }

    private var contentSection: some View {
        VStack(spacing: 0) {
            if showingAcknowledgements {
                AcknowledgementsView()
            } else {
                ContributorsView()
            }
        }
        .padding(.horizontal)
    }
}
