//
//  MiniRangeSlider.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/11.
//

import SwiftUI

struct MiniRangeSlider: View {
    @Binding var range: ClosedRange<Double>
    var bounds: ClosedRange<Double>

    private let thumbDiameter: CGFloat = 14
    private let trackHeight: CGFloat = 3
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let lowerPos = position(for: range.lowerBound, width: width)
            let upperPos = position(for: range.upperBound, width: width)

            ZStack(alignment: .leading) {
                // 背景轨道
                Capsule()
                    .strokeBorder(Color.secondary.opacity(0.05), lineWidth: 0.5 ) // 边框颜色和宽度
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )
                    .frame(height: trackHeight)
                // 选中范围轨道
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(upperPos - lowerPos, 0), height: trackHeight)
                    .offset(x: lowerPos)


                // 左滑块
                Circle()
                    .fill(colorScheme == .dark ? Color.gray : Color.white)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary, lineWidth: 0.05)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 0.5, x: 0.5, y: 0.5)
                    .offset(x: lowerPos)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = valueToRangeValue(value.location.x, width: width)
                                if newValue < range.upperBound && newValue >= bounds.lowerBound {
                                    range = newValue...range.upperBound
                                }
                            }
                    )

                // 右滑块
                Circle()
                    .fill(colorScheme == .dark ? Color.gray : Color.white)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary, lineWidth: 0.05)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 0.5, x: 0.5, y: 0.5)
                    .offset(x: upperPos)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = valueToRangeValue(value.location.x, width: width)
                                if newValue > range.lowerBound && newValue <= bounds.upperBound {
                                    range = range.lowerBound...newValue
                                }
                            }
                    )
            }
        }
        .frame(height: thumbDiameter)
        .controlSize(.mini)
    }

    private func position(for value: Double, width: CGFloat) -> CGFloat {
        let percentage = (value - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        let offset = percentage * (width - thumbDiameter)
        return offset
    }

    private func valueToRangeValue(_ x: CGFloat, width: CGFloat) -> Double {
        let clampedX = min(max(0, x - thumbDiameter / 2), width - thumbDiameter)
        let percentage = clampedX / (width - thumbDiameter)
        let value = bounds.lowerBound + Double(percentage) * (bounds.upperBound - bounds.lowerBound)
        return value
    }
}


