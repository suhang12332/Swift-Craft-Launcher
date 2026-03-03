//
//  MiniRangeSlider.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/11.
//

import SwiftUI
import AppKit

private final class RangeSliderCell: NSSliderCell {
    enum ActiveKnob {
        case lower, upper, inactive
    }

    var lowerValue: Double {
        didSet {
            let clamped = clampedLower(lowerValue)
            if clamped != lowerValue {
                lowerValue = clamped
            }
            if clamped != oldValue {
                controlView?.needsDisplay = true
            }
        }
    }

    var upperValue: Double {
        didSet {
            let clamped = clampedUpper(upperValue)
            if clamped != upperValue {
                upperValue = clamped
            }
            if clamped != oldValue {
                controlView?.needsDisplay = true
            }
        }
    }

    private var activeKnob: ActiveKnob = .inactive
    private var minimumGapValue: Double = 0
    private var cachedViewBounds: NSRect?
    private var cachedMinimumGap: Double?

    override init() {
        lowerValue = 0
        upperValue = 1
        super.init()
        isContinuous = true
    }

    required init(coder: NSCoder) {
        lowerValue = 0
        upperValue = 1
        super.init(coder: coder)
        isContinuous = true
    }

    private func withDoubleValue<T>(_ value: Double, _ body: () -> T) -> T {
        let saved = doubleValue
        doubleValue = value
        defer { doubleValue = saved }
        return body()
    }

    private func knobRect(for value: Double, flipped: Bool) -> NSRect {
        withDoubleValue(value) { super.knobRect(flipped: flipped) }
    }

    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let barRect = barRect(flipped: flipped)

        withDoubleValue(minValue) {
            super.drawBar(inside: barRect, flipped: flipped)
        }

        let lowerKnobRect = knobRect(for: lowerValue, flipped: flipped)
        let upperKnobRect = knobRect(for: upperValue, flipped: flipped)

        let activeRect = NSRect(
            x: lowerKnobRect.midX,
            y: barRect.minY,
            width: upperKnobRect.midX - lowerKnobRect.midX,
            height: barRect.height
        )

        guard activeRect.width > 0 else { return }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        let radius = barRect.height / 2
        NSBezierPath(roundedRect: activeRect, xRadius: radius, yRadius: radius).addClip()

        withDoubleValue(upperValue) {
            super.drawBar(inside: barRect, flipped: flipped)
        }
    }

    override func drawKnob(_ knobRect: NSRect) {
        let flipped = controlView?.isFlipped ?? false
        withDoubleValue(lowerValue) {
            super.drawKnob(super.knobRect(flipped: flipped))
        }
        withDoubleValue(upperValue) {
            super.drawKnob(super.knobRect(flipped: flipped))
        }
    }

    override func startTracking(at startPoint: NSPoint, in controlView: NSView) -> Bool {
        cachedViewBounds = controlView.bounds

        minimumGapValue = min(calculatedMinimumGap(), maxValue - minValue)
        cachedMinimumGap = minimumGapValue

        let flipped = controlView.isFlipped
        let lowerKnob = knobRect(for: lowerValue, flipped: flipped)
        let upperKnob = knobRect(for: upperValue, flipped: flipped)

        activeKnob = (lowerKnob.contains(startPoint) ||
                     squaredDistance(from: startPoint, to: lowerKnob.centerPoint) <
                     squaredDistance(from: startPoint, to: upperKnob.centerPoint)) ? .lower : .upper

        doubleValue = (activeKnob == .lower) ? lowerValue : upperValue
        _ = super.startTracking(at: startPoint, in: controlView)
        return true
    }

    override func continueTracking(last lastPoint: NSPoint, current currentPoint: NSPoint, in controlView: NSView) -> Bool {
        guard activeKnob != .inactive else { return false }

        if let cachedBounds = cachedViewBounds, cachedBounds == controlView.bounds, let cached = cachedMinimumGap {
            minimumGapValue = cached
        } else {
            minimumGapValue = min(calculatedMinimumGap(), maxValue - minValue)
            cachedViewBounds = controlView.bounds
            cachedMinimumGap = minimumGapValue
        }

        doubleValue = (activeKnob == .lower) ? lowerValue : upperValue
        super.continueTracking(last: lastPoint, current: currentPoint, in: controlView)
        let newValue = min(max(doubleValue, minValue), maxValue)

        switch activeKnob {
        case .lower:
            lowerValue = min(newValue, max(upperValue - minimumGapValue, minValue))
        case .upper:
            upperValue = max(newValue, min(lowerValue + minimumGapValue, maxValue))
        case .inactive:
            break
        }

        if let slider = controlView as? RangeNSSlider {
            slider.sendAction(slider.action, to: slider.target)
        }

        return true
    }

    override func stopTracking(last lastPoint: NSPoint, current stopPoint: NSPoint, in controlView: NSView, mouseIsUp flag: Bool) {
        super.stopTracking(last: lastPoint, current: stopPoint, in: controlView, mouseIsUp: flag)
        activeKnob = .inactive
        cachedViewBounds = nil
        cachedMinimumGap = nil
    }

    private func clampedLower(_ value: Double) -> Double {
        min(max(value, minValue), max(upperValue - minimumGapValue, minValue))
    }

    private func clampedUpper(_ value: Double) -> Double {
        max(min(value, maxValue), min(lowerValue + minimumGapValue, maxValue))
    }

    private func squaredDistance(from point: NSPoint, to center: NSPoint) -> CGFloat {
        let dx = point.x - center.x
        let dy = point.y - center.y
        return dx * dx + dy * dy
    }

    private func calculatedMinimumGap() -> Double {
        let track = self.trackRect
        let visualKnobSize = max(self.knobThickness - 3, 0)
        let usableWidth = max(track.width - visualKnobSize, 1)
        return Double(visualKnobSize / usableWidth) * (maxValue - minValue)
    }
}

private extension NSRect {
    var centerPoint: NSPoint {
        NSPoint(x: midX, y: midY)
    }
}

final class RangeNSSlider: NSSlider {
    private let rangeCell = RangeSliderCell()

    var lowerValue: Double {
        get { rangeCell.lowerValue }
        set { rangeCell.lowerValue = max(minValue, min(newValue, upperValue)) }
    }

    var upperValue: Double {
        get { rangeCell.upperValue }
        set { rangeCell.upperValue = min(maxValue, max(newValue, lowerValue)) }
    }

    override var minValue: Double {
        didSet { rangeCell.minValue = minValue }
    }

    override var maxValue: Double {
        didSet { rangeCell.maxValue = maxValue }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        cell = rangeCell
        isContinuous = true
    }
}

struct MiniRangeSlider: NSViewRepresentable {
    @Binding var range: ClosedRange<Double>
    var bounds: ClosedRange<Double>

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> RangeNSSlider {
        let slider = RangeNSSlider()
        slider.minValue = bounds.lowerBound
        slider.maxValue = bounds.upperBound
        slider.lowerValue = range.lowerBound
        slider.upperValue = range.upperBound
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.valueChanged(_:))
        return slider
    }

    func updateNSView(_ nsView: RangeNSSlider, context: Context) {
        var needsUpdate = false

        if abs(nsView.minValue - bounds.lowerBound) > 1e-10 {
            nsView.minValue = bounds.lowerBound
            needsUpdate = true
        }
        if abs(nsView.maxValue - bounds.upperBound) > 1e-10 {
            nsView.maxValue = bounds.upperBound
            needsUpdate = true
        }
        if abs(nsView.lowerValue - range.lowerBound) > 1e-10 {
            nsView.lowerValue = range.lowerBound
            needsUpdate = true
        }
        if abs(nsView.upperValue - range.upperBound) > 1e-10 {
            nsView.upperValue = range.upperBound
            needsUpdate = true
        }

        if needsUpdate {
            nsView.needsDisplay = true
        }
    }

    final class Coordinator: NSObject {
        var parent: MiniRangeSlider

        init(_ parent: MiniRangeSlider) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: RangeNSSlider) {
            parent.range = sender.lowerValue...sender.upperValue
        }
    }
}
