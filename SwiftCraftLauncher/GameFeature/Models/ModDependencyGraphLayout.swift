//
//  ModDependencyGraphLayout.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CoreGraphics
import Foundation

/// Deterministic mind-map style layout for the mod dependency graph.
///
/// Every mod appears exactly once. Mods are arranged in columns from left to
/// right, with each dependency pointing to the mods that require it. Shared
/// libraries therefore fan out to several dependents from a single node.
/// Deterministic jitter and vertical relaxation keep the result from looking like
/// a rigid grid without introducing overlaps or changing between launches.
struct ModDependencyGraphLayout: Sendable {
    struct Node: Identifiable, Sendable {
        let mod: ModDependencyGraph.Node
        let frame: CGRect

        var id: String { mod.id }
    }

    typealias Edge = ModDependencyGraph.Edge

    static let gameNodeID = "game"
    static let gameCardSize = CGSize(width: 210, height: 56)
    static let nodeSize = CGSize(width: 210, height: 56)
    static let layerSpacing: CGFloat = 96
    static let verticalSpacing: CGFloat = 28
    static let contentPadding: CGFloat = 44

    let rootFrame: CGRect
    let nodes: [Node]
    let edges: [Edge]
    let size: CGSize
    /// Node frames keyed by id, including the game root.
    let framesByNodeID: [String: CGRect]

    init(
        nodes graphNodes: [ModDependencyGraph.Node],
        edges graphEdges: [ModDependencyGraph.Edge],
    ) {
        // Modrinth dependency edges point from the dependent mod to the required
        // project. The board shows the inverse: required project -> dependent mod.
        // Remove transitive shortcuts before placing nodes so only the shortest
        // dependency paths are drawn.
        let invertedEdges = graphEdges.map {
            ModDependencyGraph.Edge(from: $0.to, to: $0.from)
        }
        let displayEdges = Self.transitiveReduction(invertedEdges)
        let parentsById = Self.parentsById(displayEdges)
        let childrenById = Self.childrenById(displayEdges)
        let layoutDepths = Self.layoutDepths(
            nodes: graphNodes,
            parentsById: parentsById,
            childrenById: childrenById,
        )
        let modLayerCount = layoutDepths.values.reduce(0) { max($0, $1) } + 1
        let isolatedNodes = graphNodes
            .filter { parentsById[$0.id] == nil && childrenById[$0.id] == nil }
            .sorted { Self.titleOrder($0, $1) }
        let isolatedIDs = Set(isolatedNodes.map(\.id))

        var layers = Array(repeating: [ModDependencyGraph.Node](), count: modLayerCount)
        for node in graphNodes {
            let depth = layoutDepths[node.id]!
            layers[depth].append(node)
        }
        Self.orderLayers(
            &layers,
            parentsById: parentsById,
            childrenById: childrenById,
        )

        let activeLayers = layers.map { layer in
            layer.filter { !isolatedIDs.contains($0.id) }
        }
        let rawY = Self.verticalPositions(
            layers: activeLayers,
            parentsById: parentsById,
            childrenById: childrenById,
        )
        let isolatedY = Self.verticalPositions(
            layers: [isolatedNodes],
            parentsById: parentsById,
            childrenById: childrenById,
        )

        let gameX = isolatedNodes.isEmpty
            ? 0
            : Self.contentPadding + Self.nodeSize.width + Self.layerSpacing
        let modStartX = gameX + Self.gameCardSize.width + Self.layerSpacing
        var layoutNodes: [Node] = []

        for (layerIndex, layer) in activeLayers.enumerated() {
            let baseX = modStartX + CGFloat(layerIndex) * (Self.nodeSize.width + Self.layerSpacing)

            for node in layer {
                let frame = CGRect(
                    origin: CGPoint(
                        x: baseX + Self.jitter(
                            for: node.id,
                            salt: 0x9E37_79B9_7F4A_7C15,
                            range: -42 ... 42,
                        ),
                        y: rawY[node.id]! + Self.jitter(
                            for: node.id,
                            salt: 0xC2B2_AE3D_27D4_EB4F,
                            range: -11 ... 11,
                        ),
                    ),
                    size: Self.nodeSize,
                )
                layoutNodes.append(Node(
                    mod: node,
                    frame: frame,
                ))
            }
        }

        for node in isolatedNodes {
            let frame = CGRect(
                x: Self.contentPadding + Self.jitter(
                    for: node.id,
                    salt: 0x9E37_79B9_7F4A_7C15,
                    range: -11 ... 11,
                ),
                y: isolatedY[node.id]! + Self.jitter(
                    for: node.id,
                    salt: 0xC2B2_AE3D_27D4_EB4F,
                    range: -11 ... 11,
                ),
                width: Self.nodeSize.width,
                height: Self.nodeSize.height,
            )
            layoutNodes.append(Node(mod: node, frame: frame))
        }

        // Every acyclic component connects its parentless nodes to the game
        // root. Components made entirely of dependency cycles have no parentless
        // node, so they contribute one deterministic entry point instead.
        let rootTargetNodes = Self.rootTargetNodes(
            nodes: graphNodes,
            edges: displayEdges,
            parentsById: parentsById,
            layoutDepths: layoutDepths,
        )
        let rootTargetIDs = Set(rootTargetNodes.map(\.id))
        let rootTargetCenters = layoutNodes
            .filter { rootTargetIDs.contains($0.id) }
            .map(\.frame.midY)
        let rootCenterY = rootTargetCenters.isEmpty
            ? 0
            : rootTargetCenters.reduce(0, +) / CGFloat(rootTargetCenters.count)
        let rootFrame = CGRect(
            x: gameX,
            y: rootCenterY - Self.gameCardSize.height / 2,
            width: Self.gameCardSize.width,
            height: Self.gameCardSize.height,
        )

        let bounds = layoutNodes.reduce(rootFrame) { currentBounds, node in
            currentBounds.union(node.frame)
        }
        let minX = bounds.minX
        let maxX = bounds.maxX
        let minY = bounds.minY
        let maxY = bounds.maxY
        let contentWidth = max(maxX - minX + Self.contentPadding * 2, 320)
        let contentHeight = max(maxY - minY + Self.contentPadding * 2, 320)
        let extraX = contentWidth - (maxX - minX) - Self.contentPadding * 2
        let extraY = contentHeight - (maxY - minY) - Self.contentPadding * 2
        let shift = CGPoint(
            x: Self.contentPadding - minX + extraX / 2,
            y: Self.contentPadding - minY + extraY / 2,
        )

        layoutNodes = layoutNodes.map { node in
            Node(
                mod: node.mod,
                frame: node.frame.offsetBy(dx: shift.x, dy: shift.y),
            )
        }
        layoutNodes.sort {
            $0.frame.minX == $1.frame.minX
                ? $0.frame.minY < $1.frame.minY
                : $0.frame.minX < $1.frame.minX
        }

        let shiftedRootFrame = rootFrame.offsetBy(dx: shift.x, dy: shift.y)

        var allEdges = displayEdges
        allEdges.append(contentsOf: rootTargetNodes.map {
            ModDependencyGraph.Edge(from: Self.gameNodeID, to: $0.id)
        })
        edges = allEdges

        self.rootFrame = shiftedRootFrame
        nodes = layoutNodes
        size = CGSize(width: contentWidth, height: contentHeight)

        var frames: [String: CGRect] = [Self.gameNodeID: shiftedRootFrame]
        for node in layoutNodes {
            frames[node.id] = node.frame
        }
        framesByNodeID = frames
    }

    /// Nodes that connect directly to the game root.
    ///
    /// Acyclic components contribute every parentless node. Cycle-only
    /// components contribute one representative so they are never left
    /// disconnected from the game card.
    private static func rootTargetNodes(
        nodes: [ModDependencyGraph.Node],
        edges: [ModDependencyGraph.Edge],
        parentsById: [String: [String]],
        layoutDepths: [String: Int],
    ) -> [ModDependencyGraph.Node] {
        var targets = nodes.filter { parentsById[$0.id] == nil }
        targets.append(contentsOf: cycleOnlyComponentRepresentatives(
            nodes: nodes,
            edges: edges,
            parentsById: parentsById,
            layoutDepths: layoutDepths,
        ))
        targets.sort(by: titleOrder)
        return targets
    }

    private static func cycleOnlyComponentRepresentatives(
        nodes: [ModDependencyGraph.Node],
        edges: [ModDependencyGraph.Edge],
        parentsById: [String: [String]],
        layoutDepths: [String: Int],
    ) -> [ModDependencyGraph.Node] {
        var adjacency: [String: [String]] = [:]
        for edge in edges {
            adjacency[edge.from, default: []].append(edge.to)
            adjacency[edge.to, default: []].append(edge.from)
        }

        let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        var visited: Set<String> = []
        var representatives: [ModDependencyGraph.Node] = []

        for node in nodes {
            guard visited.insert(node.id).inserted else { continue }

            var component: [String] = []
            var queue = [node.id]
            var index = 0
            while index < queue.count {
                let id = queue[index]
                index += 1
                component.append(id)
                for next in adjacency[id] ?? [] where visited.insert(next).inserted {
                    queue.append(next)
                }
            }

            guard !component.contains(where: { parentsById[$0] == nil }) else {
                continue
            }

            let componentNodes = component.map { nodeByID[$0]! }
            let representative = componentNodes.min(by: { lhs, rhs in
                let lhsDepth = layoutDepths[lhs.id]!
                let rhsDepth = layoutDepths[rhs.id]!
                if lhsDepth != rhsDepth {
                    return lhsDepth < rhsDepth
                }
                return titleOrder(lhs, rhs)
            })
            if let representative {
                representatives.append(representative)
            }
        }

        return representatives
    }

    private static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private static func jitter(
        for id: String,
        salt: UInt64,
        range: ClosedRange<CGFloat>,
    ) -> CGFloat {
        let hash = stableHash(id) ^ salt
        let unit = CGFloat(hash % 1000) / 1000
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    private static func parentsById(
        _ edges: [ModDependencyGraph.Edge],
    ) -> [String: [String]] {
        var parentsById: [String: [String]] = [:]
        for edge in edges {
            parentsById[edge.to, default: []].append(edge.from)
        }
        return parentsById
    }

    private static func childrenById(
        _ edges: [ModDependencyGraph.Edge],
    ) -> [String: [String]] {
        var childrenById: [String: [String]] = [:]
        for edge in edges {
            childrenById[edge.from, default: []].append(edge.to)
        }
        return childrenById
    }

    /// Drops edges that are already implied by a longer dependency path. For
    /// example, `C -> A` is removed when `C -> B -> A` exists, which keeps the
    /// board readable without losing reachability.
    private static func transitiveReduction(
        _ edges: [ModDependencyGraph.Edge],
    ) -> [ModDependencyGraph.Edge] {
        var adjacency: [String: [String]] = [:]
        for edge in edges {
            adjacency[edge.from, default: []].append(edge.to)
        }

        return edges.filter { edge in
            !hasAlternatePath(
                from: edge.from,
                to: edge.to,
                adjacency: adjacency,
            )
        }
    }

    private static func hasAlternatePath(
        from source: String,
        to target: String,
        adjacency: [String: [String]],
    ) -> Bool {
        var queue = [source]
        var visited: Set<String> = [source]
        var index = 0

        while index < queue.count {
            let node = queue[index]
            index += 1

            for next in adjacency[node] ?? [] {
                if node == source, next == target {
                    continue
                }
                if next == target {
                    return true
                }
                if visited.insert(next).inserted {
                    queue.append(next)
                }
            }
        }

        return false
    }

    /// Longest-path layering keeps dependency edges pointing to the right. Back
    /// edges introduced by dependency cycles are skipped for layout purposes.
    ///
    /// A DFS postorder produces a topological order once back edges are ignored;
    /// relaxing that order in a single pass computes the longest path in O(V + E)
    /// without revisiting shared subtrees.
    private static func layoutDepths(
        nodes: [ModDependencyGraph.Node],
        parentsById: [String: [String]],
        childrenById: [String: [String]],
    ) -> [String: Int] {
        var titleOrderIndex: [String: Int] = [:]
        titleOrderIndex.reserveCapacity(nodes.count)
        for (index, node) in nodes.sorted(by: titleOrder).enumerated() {
            titleOrderIndex[node.id] = index
        }

        // Sort adjacency so cycle breaking does not depend on scan order.
        let orderedChildren = childrenById.mapValues { childIDs in
            childIDs.sorted {
                titleOrderIndex[$0]! < titleOrderIndex[$1]!
            }
        }

        var visited: Set<String> = []
        var postorder: [String] = []
        postorder.reserveCapacity(nodes.count)

        func visit(_ id: String) {
            guard visited.insert(id).inserted else {
                return
            }
            for child in orderedChildren[id] ?? [] {
                visit(child)
            }
            postorder.append(id)
        }

        let orderedNodes = nodes.sorted(by: titleOrder)
        for node in orderedNodes where parentsById[node.id] == nil {
            visit(node.id)
        }
        for node in orderedNodes {
            visit(node.id)
        }

        let topologicalOrder = Array(postorder.reversed())
        var topologicalIndex: [String: Int] = [:]
        topologicalIndex.reserveCapacity(topologicalOrder.count)
        for (index, id) in topologicalOrder.enumerated() {
            topologicalIndex[id] = index
        }

        var depths: [String: Int] = [:]
        depths.reserveCapacity(nodes.count)
        for node in nodes {
            depths[node.id] = 0
        }

        for id in topologicalOrder {
            let nextDepth = depths[id]! + 1
            for child in orderedChildren[id] ?? [] {
                // Back edges are the only edges pointing backwards in reverse
                // postorder; skipping them breaks dependency cycles.
                guard topologicalIndex[child]! > topologicalIndex[id]! else {
                    continue
                }
                if nextDepth > depths[child]! {
                    depths[child] = nextDepth
                }
            }
        }

        return depths
    }

    /// Alternating downward/upward barycenter sweeps reduce edge crossings while
    /// keeping each layer's nodes in a deterministic order.
    private static func orderLayers(
        _ layers: inout [[ModDependencyGraph.Node]],
        parentsById: [String: [String]],
        childrenById: [String: [String]],
    ) {
        for layer in layers.indices {
            layers[layer].sort(by: titleOrder)
        }

        for _ in 0 ..< 2 {
            var ranks = rankByNodeID(layers)

            if layers.count > 1 {
                for layerIndex in 1 ..< layers.count {
                    layers[layerIndex].sort { lhs, rhs in
                        compareByNeighbors(
                            lhs,
                            rhs,
                            neighborIDs: parentsById,
                            ranks: ranks,
                        )
                    }
                    updateRanks(for: layers[layerIndex], in: &ranks)
                }
            }

            if layers.count > 1 {
                for layerIndex in stride(from: layers.count - 2, through: 0, by: -1) {
                    layers[layerIndex].sort { lhs, rhs in
                        compareByNeighbors(
                            lhs,
                            rhs,
                            neighborIDs: childrenById,
                            ranks: ranks,
                        )
                    }
                    updateRanks(for: layers[layerIndex], in: &ranks)
                }
            }
        }
    }

    private static func rankByNodeID(
        _ layers: [[ModDependencyGraph.Node]],
    ) -> [String: Double] {
        var ranks: [String: Double] = [:]
        for layer in layers {
            updateRanks(for: layer, in: &ranks)
        }
        return ranks
    }

    private static func updateRanks(
        for layer: [ModDependencyGraph.Node],
        in ranks: inout [String: Double],
    ) {
        for (index, node) in layer.enumerated() {
            ranks[node.id] = Double(index)
        }
    }

    private static func compareByNeighbors(
        _ lhs: ModDependencyGraph.Node,
        _ rhs: ModDependencyGraph.Node,
        neighborIDs: [String: [String]],
        ranks: [String: Double],
    ) -> Bool {
        let lhsRank = barycenter(for: lhs.id, neighborIDs: neighborIDs, ranks: ranks)
        let rhsRank = barycenter(for: rhs.id, neighborIDs: neighborIDs, ranks: ranks)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        return titleOrder(lhs, rhs)
    }

    private static func barycenter(
        for id: String,
        neighborIDs: [String: [String]],
        ranks: [String: Double],
    ) -> Double {
        let neighborRanks = (neighborIDs[id] ?? []).compactMap { ranks[$0] }
        guard !neighborRanks.isEmpty else {
            return .greatestFiniteMagnitude
        }
        return neighborRanks.reduce(0, +) / Double(neighborRanks.count)
    }

    /// Relaxes the vertical coordinates so every node sits near the average of its
    /// parents and children. The PAVA projection keeps nodes in order while
    /// enforcing a minimum gap, which avoids overlaps without creating the large
    /// empty gaps of a purely greedy placement.
    private static func verticalPositions(
        layers: [[ModDependencyGraph.Node]],
        parentsById: [String: [String]],
        childrenById: [String: [String]],
    ) -> [String: CGFloat] {
        let spacing = nodeSize.height + verticalSpacing
        var positions: [String: CGFloat] = [:]

        for layer in layers {
            let start = -CGFloat(layer.count - 1) * spacing / 2
            for (index, node) in layer.enumerated() {
                positions[node.id] = start + CGFloat(index) * spacing
            }
        }

        for _ in 0 ..< 24 {
            var next = positions

            for layer in layers {
                let desired = layer.map { node -> CGFloat in
                    let current = positions[node.id]!
                    let neighborIDs = (parentsById[node.id] ?? []) + (childrenById[node.id] ?? [])
                    let neighborYs = neighborIDs.map { positions[$0]! }
                    guard !neighborYs.isEmpty else {
                        return current
                    }
                    let average = neighborYs.reduce(0, +) / CGFloat(neighborYs.count)
                    return current * 0.35 + average * 0.65
                }

                let projected = project(desired, spacing: spacing)
                for (index, node) in layer.enumerated() {
                    next[node.id] = projected[index]
                }
            }

            positions = next
        }

        return positions
    }

    /// Projection onto the set of ordered values separated by `spacing`.
    private static func project(
        _ desired: [CGFloat],
        spacing: CGFloat,
    ) -> [CGFloat] {
        var values: [CGFloat] = []
        var counts: [Int] = []

        for (index, value) in desired.enumerated() {
            values.append(value - CGFloat(index) * spacing)
            counts.append(1)

            while values.count > 1, values[values.count - 2] > values[values.count - 1] {
                let lastValue = values.removeLast()
                let lastCount = counts.removeLast()
                let previousValue = values.removeLast()
                let previousCount = counts.removeLast()
                let count = lastCount + previousCount
                values.append((lastValue * CGFloat(lastCount) + previousValue * CGFloat(previousCount)) / CGFloat(count))
                counts.append(count)
            }
        }

        var projected: [CGFloat] = []
        for (value, count) in zip(values, counts) {
            projected.append(contentsOf: repeatElement(value, count: count))
        }

        return projected.enumerated().map { index, value in
            value + CGFloat(index) * spacing
        }
    }

    private static func titleOrder(
        _ lhs: ModDependencyGraph.Node,
        _ rhs: ModDependencyGraph.Node,
    ) -> Bool {
        let comparison = lhs.title.localizedStandardCompare(rhs.title)
        if comparison != .orderedSame {
            return comparison == .orderedAscending
        }
        return lhs.id < rhs.id
    }
}
