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
    private var cachedTrackRect: NSRect?
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

    override func drawBar(inside rect: NSRect, flipped: Bool) {
        guard let view = controlView else {
            super.drawBar(inside: rect, flipped: flipped)
            return
        }

        // 只绘制一次背景
        super.drawBar(inside: rect, flipped: flipped)

        let track = self.trackRect
        let lowerKnob = knobRectForValue(lowerValue, track: track, viewBounds: view.bounds)
        let upperKnob = knobRectForValue(upperValue, track: track, viewBounds: view.bounds)

        let barHeight = rect.height
        let activeRect = NSRect(
            x: lowerKnob.midX,
            y: rect.midY - barHeight / 2,
            width: upperKnob.midX - lowerKnob.midX,
            height: barHeight
        )

        guard activeRect.width > 0 else { return }

        NSGraphicsContext.saveGraphicsState()

        let radius = barHeight / 2
        let roundedPath = NSBezierPath(roundedRect: activeRect, xRadius: radius, yRadius: radius)
        roundedPath.addClip()

        // 直接填充激活区域，避免再次调用 super.drawBar
        NSColor.controlAccentColor.setFill()
        roundedPath.fill()

        NSGraphicsContext.restoreGraphicsState()
    }

    override func drawKnob(_ knobRect: NSRect) {
        guard let view = controlView else { return }
        let track = self.trackRect
        super.drawKnob(knobRectForValue(lowerValue, track: track, viewBounds: view.bounds))
        super.drawKnob(knobRectForValue(upperValue, track: track, viewBounds: view.bounds))
    }

    override func startTracking(at startPoint: NSPoint, in controlView: NSView) -> Bool {
        // 缓存视图边界和轨道矩形
        cachedViewBounds = controlView.bounds
        cachedTrackRect = self.trackRect

        // 计算并缓存最小间隔值
        minimumGapValue = min(calculatedMinimumGap(for: controlView.bounds), maxValue - minValue)
        cachedMinimumGap = minimumGapValue

        let track = self.trackRect
        let lowerKnob = knobRectForValue(lowerValue, track: track, viewBounds: controlView.bounds)
        let upperKnob = knobRectForValue(upperValue, track: track, viewBounds: controlView.bounds)

        // 使用平方距离比较，避免计算平方根
        activeKnob = (lowerKnob.contains(startPoint) ||
                     squaredDistance(from: startPoint, to: lowerKnob.centerPoint) <
                     squaredDistance(from: startPoint, to: upperKnob.centerPoint)) ? .lower : .upper
        return true
    }

    override func continueTracking(last lastPoint: NSPoint, current currentPoint: NSPoint, in controlView: NSView) -> Bool {
        guard activeKnob != .inactive else { return false }

        // 如果视图大小没有变化，使用缓存的 minimumGapValue
        if let cachedBounds = cachedViewBounds, cachedBounds == controlView.bounds, let cached = cachedMinimumGap {
            minimumGapValue = cached
        } else {
            minimumGapValue = min(calculatedMinimumGap(for: controlView.bounds), maxValue - minValue)
            cachedViewBounds = controlView.bounds
            cachedMinimumGap = minimumGapValue
        }

        let newValue = value(for: currentPoint, viewBounds: controlView.bounds)

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
        activeKnob = .inactive
        // 清除缓存
        cachedViewBounds = nil
        cachedTrackRect = nil
        cachedMinimumGap = nil
    }

    private func knobRectForValue(_ value: Double, track: NSRect, viewBounds: NSRect) -> NSRect {
        let knobSize = self.knobThickness
        let usableWidth = max(track.width - knobSize, 1)
        let ratio = CGFloat((value - minValue) / (maxValue - minValue))
        return NSRect(
            x: track.minX + ratio * usableWidth,
            y: track.midY - knobSize / 2,
            width: knobSize,
            height: knobSize
        )
    }

    private func value(for point: NSPoint, viewBounds: NSRect) -> Double {
        let track = self.trackRect
        let knobSize = self.knobThickness
        let usableWidth = max(track.width - knobSize, 1)
        let minX = track.minX + knobSize / 2
        let clampedX = min(max(point.x, minX), track.maxX - knobSize / 2)
        let ratio = (clampedX - minX) / usableWidth
        return minValue + Double(ratio) * (maxValue - minValue)
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

    private func distance(from point: NSPoint, to center: NSPoint) -> CGFloat {
        sqrt(squaredDistance(from: point, to: center))
    }

    private func calculatedMinimumGap(for viewBounds: NSRect) -> Double {
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
        // 批量更新，减少不必要的属性设置
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

        // 只有在值真正改变时才触发重绘
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
