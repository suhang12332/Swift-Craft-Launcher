//
//  MainView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/5/30.
//
//  根视图：仅持有 interfaceLayoutStyle、columnVisibility 等顶层状态，
//  filterState/detailState 已下沉至 MainContentArea，减少不必要的重建。
//

import SwiftUI

struct MainView: View {
    @StateObject private var general = GeneralSettingsManager.shared

    var body: some View {
        MainContentArea(interfaceLayoutStyle: general.interfaceLayoutStyle)
            .frame(minWidth: 900, minHeight: 500)
    }
}
