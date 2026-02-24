//
//  MainView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/5/30.
//
//

import SwiftUI

struct MainView: View {
    @StateObject private var general = GeneralSettingsManager.shared

    var body: some View {
        MainContentArea(interfaceLayoutStyle: general.interfaceLayoutStyle)
            .frame(minWidth: 900, minHeight: 500)
    }
}
