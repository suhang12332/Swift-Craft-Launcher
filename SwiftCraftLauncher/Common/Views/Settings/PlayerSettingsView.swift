import SwiftUI

public struct PlayerSettingsView: View {
    public init() {}
    public var body: some View {
        Grid(alignment: .center) {
            GridRow {
                Text("settings.player.title".localized())
                    .gridColumnAlignment(.trailing)
                Text("settings.player.placeholder".localized())
                    .gridColumnAlignment(.leading)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
} 
