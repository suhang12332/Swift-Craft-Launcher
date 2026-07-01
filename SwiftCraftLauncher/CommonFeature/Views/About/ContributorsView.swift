//
//  ContributorsView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays the list of project contributors from both GitHub and static sources.
public struct ContributorsView: View {
    @StateObject private var viewModel = ContributorsViewModel()
    @StateObject private var staticViewModel = ContributorsStaticViewModel()

    public init() { }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading {
                    loadingView
                } else {
                    contributorsContent
                }
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            Task { await viewModel.fetchContributors() }
            staticViewModel.load()
        }
        .onDisappear {
            clearAllData()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    private var contributorsContent: some View {
        VStack(spacing: 16) {
            if !viewModel.contributors.isEmpty {
                contributorsList
            }
            if staticViewModel.loaded, !staticViewModel.loadFailed {
                staticContributorsList
            }
        }
    }

    private var staticContributorsList: some View {
        VStack(spacing: 0) {
            Text("contributors.core_contributors".localized())
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(staticViewModel.contributors.indices, id: \.self) { index in
                StaticContributorCardView(
                    contributor: staticViewModel.contributors[index],
                )
                    .id("static-\(index)")

                if index < staticViewModel.contributors.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private var contributorsList: some View {
        VStack(spacing: 0) {
            Text("contributors.github_contributors".localized())
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !viewModel.topContributors.isEmpty {
                ForEach(
                    Array(viewModel.topContributors.enumerated()),
                    id: \.element.id,
                ) { index, contributor in
                    ContributorCardView(
                        contributor: contributor,
                        isTopContributor: true,
                        rank: index + 1,
                        contributionsText: String(
                            format: "contributors.contributions.format"
                                .localized(),
                            viewModel.formatContributions(
                                contributor.contributions,
                            ),
                        ),
                    )
                    .id("top-\(contributor.id)")

                    if index < viewModel.topContributors.count - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }

                if !viewModel.otherContributors.isEmpty {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }

            ForEach(
                Array(viewModel.otherContributors.enumerated()),
                id: \.element.id,
            ) { index, contributor in
                ContributorCardView(
                    contributor: contributor,
                    isTopContributor: false,
                    rank: index + viewModel.topContributors.count + 1,
                    contributionsText: String(
                        format: "contributors.contributions.format"
                            .localized(),
                        viewModel.formatContributions(
                            contributor.contributions,
                        ),
                    ),
                )
                .id("other-\(contributor.id)")

                if index < viewModel.otherContributors.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private func clearAllData() {
        staticViewModel.clearAllData()
        viewModel.clearContributors()
        AppLog.common.info("All contributors data cleared")
    }
}
