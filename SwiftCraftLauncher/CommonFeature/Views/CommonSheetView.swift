//
//  CommonSheetView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A sheet view with header, body, and footer sections that adapts to content size.
struct CommonSheetView<Header: View, BodyContent: View, Footer: View>: View {
    @ObservedObject private var generalSettings: GeneralSettingsManager
    private let header: () -> Header
    private let bodyContent: () -> BodyContent
    private let footer: () -> Footer

    init(
        generalSettings: GeneralSettingsManager = AppServices.generalSettingsManager,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder body: @escaping () -> BodyContent,
        @ViewBuilder footer: @escaping () -> Footer,
    ) {
        self.generalSettings = generalSettings
        self.header = header
        bodyContent = body
        self.footer = footer
    }

    var body: some View {
        VStack(spacing: 0) {
            header()
                .padding(.horizontal)
                .padding()
            Divider()
            if generalSettings.limitCommonSheetHeight {
                ScrollView {
                    bodyContent()
                        .padding(.horizontal)
                        .padding()
                }
                .frame(maxHeight: 400)
            } else {
                bodyContent()
                    .padding(.horizontal)
                    .padding()
            }
            Divider()
            footer()
                .padding(.horizontal)
                .padding()
        }
    }
}

extension CommonSheetView where Header == EmptyView, Footer == EmptyView {
    init(
        generalSettings: GeneralSettingsManager = AppServices.generalSettingsManager,
        @ViewBuilder body: @escaping () -> BodyContent,
    ) {
        self.generalSettings = generalSettings
        header = { EmptyView() }
        bodyContent = body
        footer = { EmptyView() }
    }
}

extension CommonSheetView where Footer == EmptyView {
    init(
        generalSettings: GeneralSettingsManager = AppServices.generalSettingsManager,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder body: @escaping () -> BodyContent,
    ) {
        self.generalSettings = generalSettings
        self.header = header
        bodyContent = body
        footer = { EmptyView() }
    }
}

extension CommonSheetView where Header == EmptyView {
    init(
        generalSettings: GeneralSettingsManager = AppServices.generalSettingsManager,
        @ViewBuilder body: @escaping () -> BodyContent,
        @ViewBuilder footer: @escaping () -> Footer,
    ) {
        self.generalSettings = generalSettings
        header = { EmptyView() }
        bodyContent = body
        self.footer = footer
    }
}
