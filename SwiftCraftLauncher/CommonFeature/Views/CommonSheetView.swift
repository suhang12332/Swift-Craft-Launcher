//
//  CommonSheetView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/1.
//

import SwiftUI

/// 通用Sheet视图组件
/// 分为头部、主体、底部三个部分，自适应内容大小
struct CommonSheetView<Header: View, BodyContent: View, Footer: View>: View {

    // MARK: - Properties
    @ObservedObject private var generalSettings: GeneralSettingsManager
    private let header: () -> Header
    private let bodyContent: () -> BodyContent
    private let footer: () -> Footer

    // MARK: - Initialization
    init(
        generalSettings: GeneralSettingsManager = AppServices.generalSettingsManager,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder body: @escaping () -> BodyContent,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.generalSettings = generalSettings
        self.header = header
        self.bodyContent = body
        self.footer = footer
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // 头部区域
            header()
                .padding(.horizontal)
                .padding()
            Divider()
            // 主体区域
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
            // 底部区域
            Divider()
            footer()
                .padding(.horizontal)
                .padding()
        }
    }
}

// MARK: - Convenience Initializers
extension CommonSheetView where Header == EmptyView, Footer == EmptyView {
    /// 只有主体内容的初始化方法
    init(
        generalSettings: GeneralSettingsManager = AppServices.generalSettingsManager,
        @ViewBuilder body: @escaping () -> BodyContent
    ) {
        self.generalSettings = generalSettings
        self.header = { EmptyView() }
        self.bodyContent = body
        self.footer = { EmptyView() }
    }
}

extension CommonSheetView where Footer == EmptyView {
    /// 有头部和主体的初始化方法
    init(
        generalSettings: GeneralSettingsManager = AppServices.generalSettingsManager,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder body: @escaping () -> BodyContent
    ) {
        self.generalSettings = generalSettings
        self.header = header
        self.bodyContent = body
        self.footer = { EmptyView() }
    }
}

extension CommonSheetView where Header == EmptyView {
    /// 有主体和底部的初始化方法
    init(
        generalSettings: GeneralSettingsManager = AppServices.generalSettingsManager,
        @ViewBuilder body: @escaping () -> BodyContent,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.generalSettings = generalSettings
        self.header = { EmptyView() }
        self.bodyContent = body
        self.footer = footer
    }
}
