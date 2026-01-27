//
//  OverflowButton.swift
//  SwiftCraftLauncher
//
//  Created by AI Assistant
//
import SwiftUI

// MARK: - Overflow Button
struct OverflowButton<Content: View>: View {
    let count: Int
    @Binding var isPresented: Bool
    let popoverContent: () -> Content
    
    init(
        count: Int,
        isPresented: Binding<Bool>,
        @ViewBuilder popoverContent: @escaping () -> Content
    ) {
        self.count = count
        self._isPresented = isPresented
        self.popoverContent = popoverContent
    }
    
    var body: some View {
        Button {
            isPresented = true
        } label: {
            Text("+\(count)")
                .font(.caption)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .leading) {
            popoverContent()
        }
    }
}
