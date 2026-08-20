//
//  ModrinthProjectDetailView.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftMarkDownUI
import SwiftUI

private enum Constants {
    static let iconSize: CGFloat = 75
    static let cornerRadius: CGFloat = 8
    static let galleryImageHeight: CGFloat = 160
    static let galleryImageMinWidth: CGFloat = 160
    static let galleryImageMaxWidth: CGFloat = 200
    static let categorySpacing: CGFloat = 6
    static let categoryPadding: CGFloat = 4
    static let categoryVerticalPadding: CGFloat = 2
    static let categoryCornerRadius: CGFloat = 12
}

/// Displays the full project detail view with icon, title, stats, and description.
struct ModrinthProjectDetailView: View {
    let projectDetail: ModrinthProjectDetail?

    var body: some View {
        if let project = projectDetail {
            projectDetailView(project)
        } else {
            loadingView
        }
    }

    private func projectDetailView(_ project: ModrinthProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            projectHeader(project)
            projectContent(project)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private func projectHeader(_ project: ModrinthProjectDetail) -> some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 12) {
                projectIcon(project)
                projectInfo(project)
            }
        }
    }

    @ViewBuilder
    private func projectIcon(_ project: ModrinthProjectDetail) -> some View {
        if let iconUrl = project.iconUrl, let url = URL(string: iconUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                default:
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 80, height: 80)
                }
            }
            .onDisappear {
                URLCache.shared.removeCachedResponse(for: URLRequest(url: url))
            }
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .cornerRadius(Constants.cornerRadius)
            .clipped()
        }
    }

    private func projectInfo(_ project: ModrinthProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.title)
                .font(.largeTitle.bold())

            Text(project.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)

            projectStats(project)
        }
    }

    private func projectStats(_ project: ModrinthProjectDetail) -> some View {
        HStack {
            Label("\(project.downloads)", systemImage: "arrow.down.circle")
            Label("\(project.followers)", systemImage: "star")

            FlowLayout(spacing: Constants.categorySpacing) {
                ForEach(project.categories, id: \.self) { category in
                    CategoryTag(text: category)
                }
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private func projectContent(_ project: ModrinthProjectDetail) -> some View {
        VStack(alignment: .leading) {
            descriptionView(project)
        }
        .padding(.vertical)
    }

    private func descriptionView(_ project: ModrinthProjectDetail) -> some View {
        RichContentView(content: project.body)
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RichContentView: View {
    let content: String

    var body: some View {
        let segments = MarkdownImageExtractor.extract(
            from: HTMLToMarkdownConverter.convertIfNeeded(content),
        )

        VStack(alignment: .leading, spacing: 0) {
            ForEach(segments) { segment in
                switch segment.content {
                case let .markdown(markdown):
                    if !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        MixedMarkdownView(markdown)
                    }
                case let .image(source):
                    BoundedMarkdownImageView(source: source)
                case let .linkedImage(source, destination):
                    BoundedMarkdownImageView(source: source, destination: destination)
                }
            }
        }
    }
}

private struct MarkdownContentSegment: Identifiable {
    enum Content {
        case markdown(String)
        case image(String)
        case linkedImage(source: String, destination: String)
    }

    let id = UUID()
    let content: Content
}

private enum MarkdownImageExtractor {
    static func extract(from markdown: String) -> [MarkdownContentSegment] {
        let pattern = #"(?m)^[ \t]*(?:\[!\[([^\]]*)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)|!\[([^\]]*)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\))[ \t]*(?:\n|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [MarkdownContentSegment(content: .markdown(markdown))]
        }

        let range = NSRange(markdown.startIndex..., in: markdown)
        let matches = regex.matches(in: markdown, range: range)
        var segments: [MarkdownContentSegment] = []
        var cursor = markdown.startIndex

        for match in matches {
            let sourceMatchRange = match.range(at: 2).location == NSNotFound
                ? match.range(at: 5)
                : match.range(at: 2)
            guard let fullRange = Range(match.range, in: markdown),
                  let sourceRange = Range(sourceMatchRange, in: markdown) else {
                continue
            }
            let prefix = markdown[cursor..<fullRange.lowerBound]
            if !prefix.isEmpty {
                segments.append(MarkdownContentSegment(content: .markdown(String(prefix))))
            }
            let content: MarkdownContentSegment.Content
            if let destinationRange = Range(match.range(at: 3), in: markdown) {
                content = .linkedImage(
                    source: String(markdown[sourceRange]),
                    destination: String(markdown[destinationRange]),
                )
            } else {
                content = .image(String(markdown[sourceRange]))
            }
            segments.append(MarkdownContentSegment(content: content))
            cursor = fullRange.upperBound
        }

        let suffix = markdown[cursor...]
        if !suffix.isEmpty {
            segments.append(MarkdownContentSegment(content: .markdown(String(suffix))))
        }
        return segments.isEmpty ? [MarkdownContentSegment(content: .markdown(markdown))] : segments
    }
}

private struct BoundedMarkdownImageView: View {
    let source: String
    let destination: String?

    init(source: String, destination: String? = nil) {
        self.source = source
        self.destination = destination
    }

    var body: some View {
        if let url = URL(string: source) {
            let image = AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .interpolation(.high)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .failure:
                    EmptyView()
                default:
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let destination, let destinationURL = URL(string: destination) {
                Link(destination: destinationURL) {
                    image
                }
            } else {
                image
            }
        }
    }
}

private struct CategoryTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, Constants.categoryPadding)
            .padding(.vertical, Constants.categoryVerticalPadding)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(Constants.categoryCornerRadius)
    }
}
