//
//  MiniRangeSlider.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// A SwiftUI view that provides a compact range slider.
struct MiniRangeSlider: View {
    @Binding var range: ClosedRange<Double>
    var bounds: ClosedRange<Double>
    /// Overrides the ambient control size for the slider's inner controls.
    var controlSize: ControlSize?

    @Environment(\.controlSize)
    private var environmentControlSize

    init(
        range: Binding<ClosedRange<Double>>,
        bounds: ClosedRange<Double>,
        controlSize: ControlSize? = nil,
    ) {
        _range = range
        self.bounds = bounds
        self.controlSize = controlSize
    }

    private var resolvedControlSize: ControlSize {
        controlSize ?? environmentControlSize
    }

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                NativeMiniRangeSlider(
                    range: $range,
                    bounds: bounds,
                    controlSize: resolvedControlSize,
                )
            } else {
                LegacyMiniRangeSlider(
                    range: $range,
                    bounds: bounds,
                    controlSize: resolvedControlSize,
                )
            }
        }
        .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
    }
}

extension ControlSize {
    /// Maps the SwiftUI control size to its AppKit counterpart.
    var nsControlSize: NSControl.ControlSize {
        switch self {
        case .mini: .mini
        case .small: .small
        case .regular: .regular
        case .large: .large
        default: .large
        }
    }
}

/// Hides the track, leaving only the native knob.
private final class InactiveRangeSliderCell: NSSliderCell {
    override func drawBar(inside _: NSRect, flipped _: Bool) {}
}

/// A range slider built from native sliders, for macOS 26 and later.
///
/// An interactive slider draws the track, its knob, and the filled portion via
/// `neutralValue`; an overlapping inactive slider draws the other knob.
@available(macOS 26.0, *)
final class NativeRangeSlider: NSControl {
    private enum ActiveKnob {
        case lower, upper
    }

    private let slider = NSSlider()
    private let inactiveSlider = NSSlider()
    private var activeKnob: ActiveKnob = .upper
    private var lowerValue: Double = 0
    private var upperValue: Double = 1

    var range: ClosedRange<Double> {
        lowerValue ... upperValue
    }

    override var controlSize: NSControl.ControlSize {
        didSet {
            guard controlSize != oldValue else { return }
            for control in [slider, inactiveSlider] {
                control.controlSize = controlSize
            }
            needsLayout = true
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: slider.intrinsicContentSize.height)
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
        // Only the inactive knob uses cell drawing; the interactive slider keeps its native renderer.
        inactiveSlider.cell = InactiveRangeSliderCell()
        inactiveSlider.refusesFirstResponder = true
        inactiveSlider.setAccessibilityElement(false)
        slider.target = self
        slider.action = #selector(valueChanged(_:))
        addSubview(slider)
        addSubview(inactiveSlider)
    }

    func setRange(_ range: ClosedRange<Double>, bounds: ClosedRange<Double>) {
        for control in [slider, inactiveSlider] {
            control.minValue = bounds.lowerBound
            control.maxValue = bounds.upperBound
        }
        lowerValue = range.lowerBound
        upperValue = range.upperBound
        updateSliders()
    }

    override func layout() {
        super.layout()
        slider.frame = bounds
        inactiveSlider.frame = bounds
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let location = convert(point, from: superview)
        if NSApp.currentEvent?.type == .leftMouseDown {
            let midpoint = (lowerValue + upperValue) / 2
            let split = knobCenterX(for: midpoint)
            let selectedKnob: ActiveKnob = location.x < split ? .lower : .upper
            if selectedKnob != activeKnob {
                activeKnob = selectedKnob
                updateSliders()
            }
        }
        return slider.hitTest(location)
    }

    /// The horizontal center of the knob for a given value.
    private func knobCenterX(for value: Double) -> CGFloat {
        let knobWidth = slider.knobThickness
        let usableWidth = max(bounds.width - knobWidth, 0)
        let span = slider.maxValue - slider.minValue
        guard span > 0 else { return bounds.midX }
        let fraction = CGFloat((value - slider.minValue) / span)
        return bounds.minX + knobWidth / 2 + fraction * usableWidth
    }

    private func updateSliders() {
        let value = activeKnob == .lower ? lowerValue : upperValue
        let inactiveValue = activeKnob == .lower ? upperValue : lowerValue
        slider.neutralValue = inactiveValue
        slider.doubleValue = value
        inactiveSlider.doubleValue = inactiveValue
    }

    @objc private func valueChanged(_ sender: NSSlider) {
        let knobWidth = slider.knobThickness
        let usableWidth = max(bounds.width - knobWidth, 1)
        let valueSpan = slider.maxValue - slider.minValue
        let minimumGap = min(Double(knobWidth / usableWidth) * valueSpan, valueSpan)
        if activeKnob == .lower {
            lowerValue = min(sender.doubleValue, max(upperValue - minimumGap, slider.minValue))
        } else {
            upperValue = max(sender.doubleValue, min(lowerValue + minimumGap, slider.maxValue))
        }
        updateSliders()
        sendAction(action, to: target)
    }
}

@available(macOS 26.0, *)
private struct NativeMiniRangeSlider: NSViewRepresentable {
    @Binding var range: ClosedRange<Double>
    var bounds: ClosedRange<Double>
    var controlSize: ControlSize

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NativeRangeSlider {
        let slider = NativeRangeSlider()
        slider.controlSize = controlSize.nsControlSize
        slider.setRange(range, bounds: bounds)
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.valueChanged(_:))
        return slider
    }

    func updateNSView(_ nsView: NativeRangeSlider, context: Context) {
        context.coordinator.parent = self
        nsView.controlSize = controlSize.nsControlSize
        nsView.setRange(range, bounds: bounds)
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: NativeMiniRangeSlider

        init(_ parent: NativeMiniRangeSlider) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: NativeRangeSlider) {
            parent.range = sender.range
        }
    }
}

// MARK: - Legacy (macOS 15 and earlier)

/// Draws only the native track, hiding the knob.
private final class TrackOnlySliderCell: NSSliderCell {
    override func drawKnob() {}

    override func drawKnob(_: NSRect) {}
}

/// Draws only the native knob, hiding the track.
private final class KnobOnlySliderCell: NSSliderCell {
    override func drawBar(inside _: NSRect, flipped _: Bool) {}
}

/// A range slider built from native sliders, for macOS 15 and earlier.
///
/// Every pixel is drawn by AppKit: two native tracks (unfilled and filled) and
/// two native knobs are layered, and the cells only suppress the half they must
/// not draw. The filled track is clipped to the selected range instead of using
/// the macOS 26 `neutralValue` API.
final class LegacyRangeSlider: NSControl {
    private enum ActiveKnob {
        case lower, upper
    }

    private let baseTrack = NSSlider()
    private let fillTrack = NSSlider()
    private let fillClip = NSView()
    private let slider = NSSlider()
    private let inactiveSlider = NSSlider()

    private var activeKnob: ActiveKnob = .upper
    private var lowerValue: Double = 0
    private var upperValue: Double = 1

    var range: ClosedRange<Double> {
        lowerValue ... upperValue
    }

    override var controlSize: NSControl.ControlSize {
        didSet {
            guard controlSize != oldValue else { return }
            for control in [baseTrack, fillTrack, slider, inactiveSlider] {
                control.controlSize = controlSize
            }
            needsLayout = true
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: slider.intrinsicContentSize.height)
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
        baseTrack.cell = TrackOnlySliderCell()
        fillTrack.cell = TrackOnlySliderCell()
        slider.cell = KnobOnlySliderCell()
        inactiveSlider.cell = KnobOnlySliderCell()

        // Only the clip geometry is custom; the track itself is still drawn by AppKit.
        fillClip.wantsLayer = true
        fillClip.clipsToBounds = true

        for control in [baseTrack, fillTrack] {
            control.isContinuous = false
            control.setAccessibilityElement(false)
        }

        inactiveSlider.refusesFirstResponder = true
        inactiveSlider.setAccessibilityElement(false)
        slider.target = self
        slider.action = #selector(valueChanged(_:))

        addSubview(baseTrack)
        fillClip.addSubview(fillTrack)
        addSubview(fillClip)
        addSubview(slider)
        addSubview(inactiveSlider)
    }

    func setRange(_ range: ClosedRange<Double>, bounds: ClosedRange<Double>) {
        for control in [baseTrack, fillTrack, slider, inactiveSlider] {
            control.minValue = bounds.lowerBound
            control.maxValue = bounds.upperBound
        }
        lowerValue = range.lowerBound
        upperValue = range.upperBound
        updateSliders()
    }

    override func layout() {
        super.layout()
        baseTrack.frame = bounds
        slider.frame = bounds
        inactiveSlider.frame = bounds
        updateFillClip()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let location = convert(point, from: superview)
        if NSApp.currentEvent?.type == .leftMouseDown {
            let midpoint = (lowerValue + upperValue) / 2
            let split = knobCenterX(for: midpoint)
            let selectedKnob: ActiveKnob = location.x < split ? .lower : .upper
            if selectedKnob != activeKnob {
                activeKnob = selectedKnob
                updateSliders()
            }
        }
        return slider.hitTest(location)
    }

    private func updateSliders() {
        let value = activeKnob == .lower ? lowerValue : upperValue
        let inactiveValue = activeKnob == .lower ? upperValue : lowerValue
        baseTrack.doubleValue = baseTrack.minValue
        fillTrack.doubleValue = fillTrack.maxValue
        slider.doubleValue = value
        inactiveSlider.doubleValue = inactiveValue
        updateFillClip()
    }

    /// Clips the filled native track to the selected range.
    private func updateFillClip() {
        let lowerX = knobCenterX(for: lowerValue)
        let upperX = knobCenterX(for: upperValue)

        let clipRect = NSRect(
            x: lowerX,
            y: bounds.minY,
            width: upperX - lowerX,
            height: bounds.height,
        )
        fillClip.frame = clipRect
        fillTrack.frame = NSRect(
            x: bounds.minX - clipRect.minX,
            y: bounds.minY - clipRect.minY,
            width: bounds.width,
            height: bounds.height,
        )
    }

    private func knobCenterX(for value: Double) -> CGFloat {
        let knobWidth = slider.knobThickness
        let usableWidth = max(bounds.width - knobWidth, 0)
        let span = slider.maxValue - slider.minValue
        guard span > 0 else { return bounds.midX }
        let fraction = CGFloat((value - slider.minValue) / span)
        return bounds.minX + knobWidth / 2 + fraction * usableWidth
    }

    @objc private func valueChanged(_ sender: NSSlider) {
        let knobWidth = slider.knobThickness
        let usableWidth = max(bounds.width - knobWidth, 1)
        let valueSpan = slider.maxValue - slider.minValue
        let minimumGap = min(Double(knobWidth / usableWidth) * valueSpan, valueSpan)
        if activeKnob == .lower {
            lowerValue = min(sender.doubleValue, max(upperValue - minimumGap, slider.minValue))
        } else {
            upperValue = max(sender.doubleValue, min(lowerValue + minimumGap, slider.maxValue))
        }
        updateSliders()
        sendAction(action, to: target)
    }
}

private struct LegacyMiniRangeSlider: NSViewRepresentable {
    @Binding var range: ClosedRange<Double>
    var bounds: ClosedRange<Double>
    var controlSize: ControlSize

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> LegacyRangeSlider {
        let slider = LegacyRangeSlider()
        slider.controlSize = controlSize.nsControlSize
        slider.setRange(range, bounds: bounds)
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.valueChanged(_:))
        return slider
    }

    func updateNSView(_ nsView: LegacyRangeSlider, context: Context) {
        context.coordinator.parent = self
        nsView.controlSize = controlSize.nsControlSize
        nsView.setRange(range, bounds: bounds)
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: LegacyMiniRangeSlider

        init(_ parent: LegacyMiniRangeSlider) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: LegacyRangeSlider) {
            parent.range = sender.range
        }
    }
}
