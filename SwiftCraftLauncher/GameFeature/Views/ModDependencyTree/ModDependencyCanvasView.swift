//
//  ModDependencyCanvasView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// Freeform-style whiteboard for browsing mod dependencies.
///
/// Nodes use a fixed automatic layout while the canvas can be panned and zoomed
/// like an infinite board.
struct ModDependencyCanvasView: View {
    let layout: ModDependencyGraphLayout
    let game: GameVersionInfo
    let projectIcons: [String: NSImage]

    @State private var zoom: CGFloat = 1
    @State private var magnifyStartZoom: CGFloat?
    @State private var selectedNodeIDs: Set<String> = []
    private let frames: [String: CGRect]
    private let rootCanvasFrame: CGRect
    private let parentsByNodeID: [String: [String]]

    private let canvasSize: CGSize

    init(
        layout: ModDependencyGraphLayout,
        game: GameVersionInfo,
        projectIcons: [String: NSImage],
    ) {
        self.layout = layout
        self.game = game
        self.projectIcons = projectIcons

        // Keep a modest margin around the graph. Large blank margins multiply
        // the backing surface size when the entire canvas is magnified.
        let width = max(layout.size.width + 160, 960)
        let height = max(layout.size.height + 160, 640)
        canvasSize = CGSize(width: width, height: height)

        let origin = CGPoint(
            x: (width - layout.size.width) / 2,
            y: (height - layout.size.height) / 2,
        )
        frames = layout.framesByNodeID.mapValues {
            $0.offsetBy(dx: origin.x, dy: origin.y)
        }
        rootCanvasFrame = layout.rootFrame.offsetBy(dx: origin.x, dy: origin.y)

        var parents: [String: [String]] = [:]
        for edge in layout.edges {
            parents[edge.to, default: []].append(edge.from)
        }
        parentsByNodeID = parents
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            canvasContent
                .scaleEffect(zoom, anchor: .topLeading)
                .frame(
                    width: canvasSize.width * zoom,
                    height: canvasSize.height * zoom,
                    alignment: .topLeading,
                )
        }
        .defaultScrollAnchor(.center)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .simultaneousGesture(magnifyGesture)
    }

    private var canvasContent: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                drawModDependencyConnections(
                    edges: layout.edges,
                    frames: frames,
                    in: &context,
                )
            }
            .frame(width: canvasSize.width, height: canvasSize.height)

            GameDependencyCard(
                game: game,
            )
            .position(x: rootCanvasFrame.midX, y: rootCanvasFrame.midY)

            ForEach(layout.nodes) { node in
                let frame = canvasFrame(for: node.id)
                ModDependencyCard(
                    node: node.mod,
                    icon: projectIcons[node.mod.projectId],
                    isSelected: selectedNodeIDs.contains(node.id),
                )
                .position(x: frame.midX, y: frame.midY)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .contentShape(Rectangle())
        .gesture(selectionGesture)
    }

    private func canvasFrame(for nodeID: String) -> CGRect {
        frames[nodeID]!
    }

    private func ancestorSelection(for id: String) -> Set<String> {
        var result: Set<String> = [id]
        var pending = [id]

        while let current = pending.popLast() {
            for parentID in parentsByNodeID[current] ?? [] where result.insert(parentID).inserted {
                pending.append(parentID)
            }
        }

        return result
    }

    private var selectionGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let point = value.location
                if let hitNode = layout.nodes.first(where: {
                    canvasFrame(for: $0.id).contains(point)
                }) {
                    selectedNodeIDs = ancestorSelection(for: hitNode.id)
                } else {
                    selectedNodeIDs.removeAll()
                }
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = magnifyStartZoom ?? zoom
                magnifyStartZoom = base
                // Large magnification multiplies backing surface memory by the
                // square of the zoom factor.
                zoom = min(2, max(0.5, base * value.magnification))
            }
            .onEnded { _ in
                magnifyStartZoom = nil
            }
    }
}

private struct DependencyConnectionPaths {
    var rootConnections = Path()
    var modConnections = Path()
    var rootArrows = Path()
    var modArrows = Path()
}

/// Draws dependency connections for both the live canvas and image export.
func drawModDependencyConnections(
    edges: [ModDependencyGraphLayout.Edge],
    frames: [String: CGRect],
    in context: inout GraphicsContext,
) {
    let paths = dependencyConnectionPaths(
        edges: edges,
        frames: frames,
    )
    let lineStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
    context.stroke(paths.rootConnections, with: .color(.accentColor.opacity(0.5)), style: lineStyle)
    context.stroke(paths.modConnections, with: .color(.secondary.opacity(0.42)), style: lineStyle)
    context.fill(paths.rootArrows, with: .color(.accentColor.opacity(0.8)))
    context.fill(paths.modArrows, with: .color(.secondary.opacity(0.65)))
}

private func dependencyConnectionPaths(
    edges: [ModDependencyGraphLayout.Edge],
    frames: [String: CGRect],
) -> DependencyConnectionPaths {
    var paths = DependencyConnectionPaths()

    for edge in edges {
        let isRootEdge = edge.from == ModDependencyGraphLayout.gameNodeID
        let source = frames[edge.from]!
        let target = frames[edge.to]!

        let isRightward = target.midX >= source.midX
        let start = CGPoint(
            x: isRightward ? source.maxX : source.minX,
            y: source.midY,
        )
        let end = CGPoint(
            x: isRightward ? target.minX : target.maxX,
            y: target.midY,
        )
        let bend = max(36, abs(end.x - start.x) * 0.45)
        let control1 = CGPoint(
            x: isRightward ? start.x + bend : start.x - bend,
            y: start.y,
        )
        let control2 = CGPoint(
            x: isRightward ? end.x - bend : end.x + bend,
            y: end.y,
        )

        if isRootEdge {
            paths.rootConnections.move(to: start)
            paths.rootConnections.addCurve(to: end, control1: control1, control2: control2)
            appendModDependencyArrowhead(at: end, control: control2, to: &paths.rootArrows)
        } else {
            paths.modConnections.move(to: start)
            paths.modConnections.addCurve(to: end, control1: control1, control2: control2)
            appendModDependencyArrowhead(at: end, control: control2, to: &paths.modArrows)
        }
    }
    return paths
}

private func appendModDependencyArrowhead(
    at end: CGPoint,
    control: CGPoint,
    to arrow: inout Path,
) {
    let angle = atan2(end.y - control.y, end.x - control.x)

    let length: CGFloat = 7
    let width: CGFloat = 4
    let base = CGPoint(
        x: end.x - length * cos(angle),
        y: end.y - length * sin(angle),
    )
    let left = CGPoint(
        x: base.x - width * sin(angle),
        y: base.y + width * cos(angle),
    )
    let right = CGPoint(
        x: base.x + width * sin(angle),
        y: base.y - width * cos(angle),
    )

    arrow.move(to: end)
    arrow.addLine(to: left)
    arrow.addLine(to: right)
    arrow.closeSubpath()
}
