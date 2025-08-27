//
//  InspectorToolbar.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/5.
//

import SwiftUI

struct InspectorToolbar: View {
    @Binding var showingInspector: Bool
    
    var body: some View {

        Spacer()
        Button(action: {
            withAnimation {
                showingInspector.toggle()
            }
        }) {
            Image(systemName: showingInspector ? "sidebar.right" : "sidebar.left")
        }
        .help((showingInspector ? "game.version.inspector.hide" : "game.version.inspector.show").localized())
    }
}
