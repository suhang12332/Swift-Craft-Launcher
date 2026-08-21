//
//  MemoryRangeLabel.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A memory-range readout (for example `512 MB-4096 MB`) whose layout width
/// stays constant while the displayed values change.
///
/// `MiniRangeSlider` mirrors its selection into this neighbouring label.
/// Because the digit count changes while dragging (`999` -> `1024`,
/// `4096` -> `8192`), a plain `Text` grows and shrinks on every value
/// change. Inside the trailing-aligned content block of a `LabeledContent`,
/// that width change shifts the slider and the adjacent reset button
/// horizontally on each tick, which the user perceives as page jitter.
///
/// This view reserves space for the widest value the bounds allow (a hidden
/// sizer rendered with the same font) so the occupied width is constant
/// regardless of the current selection. Monospaced digits additionally keep
/// same-digit-count values from wiggling pixel-by-pixel.
struct MemoryRangeLabel: View {
    /// The currently selected range to display.
    let range: ClosedRange<Double>
    /// The slider bounds. `upperBound` drives the reserved layout width.
    let bounds: ClosedRange<Double>

    private var displayText: String {
        "\(Int(range.lowerBound)) MB-\(Int(range.upperBound)) MB"
    }

    /// The widest string the bounds can produce, used only to reserve layout
    /// width so it never changes while the user drags.
    private var sizerText: String {
        let maxMegabytes = Int(max(bounds.upperBound, range.lowerBound, range.upperBound))
        return "\(maxMegabytes) MB-\(maxMegabytes) MB"
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Hidden sizer: renders the widest possible value so the ZStack
            // keeps a constant intrinsic width throughout a drag.
            Text(sizerText)
                .font(.subheadline)
                .hidden()
            Text(displayText)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(displayText)
    }
}
