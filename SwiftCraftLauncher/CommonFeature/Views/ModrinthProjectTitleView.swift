//
//  ModrinthProjectTitleView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/3.
//

import SwiftUI

struct ModrinthProjectTitleView: View {
    let projectDetail: ModrinthProjectDetail

    var body: some View {
        ServerInfoCardView(projectDetail: projectDetail)
    }
}
