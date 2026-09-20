//
//  UpdateSourceSelector.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Selects the fastest update source that serves a valid architecture-specific Sparkle appcast.
actor UpdateSourceSelector {
    typealias Probe = @Sendable (UpdateSource, String) async -> TimeInterval?

    private struct CachedSelection {
        let source: UpdateSource
        let expiresAt: Date
    }

    private let sources: [UpdateSource]
    private let fallbackSource: UpdateSource
    private let cacheDuration: TimeInterval
    private let probe: Probe
    private let now: @Sendable () -> Date
    private var cachedSelections: [String: CachedSelection] = [:]

    init(
        sources: [UpdateSource],
        fallbackSource: UpdateSource,
        cacheDuration: TimeInterval = 30 * 60,
        now: @escaping @Sendable () -> Date = { Date() },
        probe: Probe? = nil,
    ) {
        self.sources = sources
        self.fallbackSource = fallbackSource
        self.cacheDuration = cacheDuration
        self.now = now
        self.probe = probe ?? Self.probeAppcast
    }

    /// Returns the fastest healthy source, or the existing update source if every probe fails.
    func selectSource(architecture: String, forceRefresh: Bool = false) async -> UpdateSource {
        let currentDate = now()
        if !forceRefresh,
           let cachedSelection = cachedSelections[architecture],
           cachedSelection.expiresAt > currentDate {
            return cachedSelection.source
        }

        let availableSources = sources
        let appcastProbe = probe
        let measurements = await withTaskGroup(of: (UpdateSource, TimeInterval)?.self) { group in
            for source in availableSources {
                group.addTask {
                    guard let latency = await appcastProbe(source, architecture) else { return nil }
                    return (source, latency)
                }
            }

            var results: [(UpdateSource, TimeInterval)] = []
            for await result in group {
                if let result {
                    results.append(result)
                }
            }
            return results
        }

        guard let selectedSource = measurements.min(by: { lhs, rhs in
            if lhs.1 == rhs.1 {
                return sourceIndex(lhs.0) < sourceIndex(rhs.0)
            }
            return lhs.1 < rhs.1
        })?.0 else {
            return fallbackSource
        }

        cachedSelections[architecture] = CachedSelection(
            source: selectedSource,
            expiresAt: currentDate.addingTimeInterval(cacheDuration),
        )
        return selectedSource
    }

    func invalidateCache() {
        cachedSelections.removeAll()
    }

    private func sourceIndex(_ source: UpdateSource) -> Int {
        sources.firstIndex(of: source) ?? .max
    }

    private static func probeAppcast(source: UpdateSource, architecture: String) async -> TimeInterval? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        configuration.timeoutIntervalForResource = 3
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: source.appcastURL(architecture: architecture))
        request.httpMethod = "GET"
        request.timeoutInterval = 3
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/rss+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")
        request.setValue("Swift-Craft-Launcher/update-source-probe", forHTTPHeaderField: "User-Agent")

        let startTime = Date()
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  isValidAppcast(data, architecture: architecture)
            else {
                return nil
            }
            return Date().timeIntervalSince(startTime)
        } catch {
            return nil
        }
    }

    static func isValidAppcast(_ data: Data, architecture: String) -> Bool {
        guard !data.isEmpty,
              data.count <= 1024 * 1024
        else {
            return false
        }

        let validationDelegate = AppcastValidationDelegate(architecture: architecture)
        let parser = XMLParser(data: data)
        parser.delegate = validationDelegate
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        return parser.parse() && validationDelegate.isValid
    }
}

private final class AppcastValidationDelegate: NSObject, XMLParserDelegate {
    private let expectedFileNameFragment: String
    private var rootElementName: String?
    private var isInsideItem = false
    private var collectedElementName: String?
    private var collectedText = ""
    private var version = ""
    private var shortVersion = ""
    private var hasSignedEnclosure = false

    private(set) var hasValidItem = false

    var isValid: Bool {
        rootElementName == "rss" && hasValidItem
    }

    init(architecture: String) {
        expectedFileNameFragment = "Swift-Craft-Launcher-\(architecture)-"
    }

    func parser(
        _: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes attributeDict: [String: String],
    ) {
        let name = localName(elementName)
        if rootElementName == nil {
            rootElementName = name
        }

        if name == "item" {
            isInsideItem = true
            version = ""
            shortVersion = ""
            hasSignedEnclosure = false
            return
        }

        guard isInsideItem else { return }
        if name == "version" || name == "shortVersionString" {
            collectedElementName = name
            collectedText = ""
        } else if name == "enclosure" {
            validateEnclosureAttributes(attributeDict)
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        guard collectedElementName != nil else { return }
        collectedText += string
    }

    func parser(
        _: XMLParser,
        didEndElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
    ) {
        let name = localName(elementName)
        if name == collectedElementName {
            let value = collectedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if name == "version" {
                version = value
            } else if name == "shortVersionString" {
                shortVersion = value
            }
            collectedElementName = nil
            collectedText = ""
        }

        if name == "item" {
            if !version.isEmpty, !shortVersion.isEmpty, hasSignedEnclosure {
                hasValidItem = true
            }
            isInsideItem = false
        }
    }

    private func validateEnclosureAttributes(_ attributes: [String: String]) {
        guard let urlString = attribute(named: "url", in: attributes),
              let signature = attribute(named: "edSignature", in: attributes),
              let lengthString = attribute(named: "length", in: attributes),
              let length = Int64(lengthString),
              length > 0,
              !signature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }

        let fileName = URL(string: urlString)?.lastPathComponent ?? ""
        if fileName.contains(expectedFileNameFragment) {
            hasSignedEnclosure = true
        }
    }

    private func attribute(named name: String, in attributes: [String: String]) -> String? {
        attributes.first { localName($0.key) == name }?.value
    }

    private func localName(_ qualifiedName: String) -> String {
        String(qualifiedName.split(separator: ":").last ?? Substring(qualifiedName))
    }
}
