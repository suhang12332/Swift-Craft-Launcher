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

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let lowerPos = position(for: range.lowerBound, width: width)
            let upperPos = position(for: range.upperBound, width: width)

            ZStack(alignment: .leading) {
                // 背景轨道
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: trackHeight)

                // 选中范围轨道
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(upperPos - lowerPos, 0), height: trackHeight)
                    .offset(x: lowerPos)

                // 左滑块
                Circle()
                    .fill(.background)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(radius: 1)
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
                    .fill(.background)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .shadow(radius: 1)
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
