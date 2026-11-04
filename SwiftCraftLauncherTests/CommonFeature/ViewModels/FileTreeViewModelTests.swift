//
//  FileTreeViewModelTests.swift
//  SwiftCraftLauncherTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

@testable import SwiftCraftLauncher
import XCTest

final class FileTreeViewModelTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileTreeViewModelTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testDefaultSelectionDoesNotLoadChildDirectories() throws {
        try makeFile("mods/sub/example.jar")
        try makeFile("config/config.json")
        try makeFile("options.txt")

        let viewModel = FileTreeViewModel(rootURL: tempDirectory, showHiddenFiles: false)
        viewModel.applyDefaultSelectionIfNeeded()

        let mods = try XCTUnwrap(child(named: "mods", of: viewModel.root))
        XCTAssertTrue(mods.selection == .all)
        XCTAssertNil(mods.children, "默认选择不应递归加载子目录")

        let selectedPaths = Set(viewModel.selectedRootURLs().map(\.standardizedFileURL.path))
        XCTAssertTrue(selectedPaths.contains(tempDirectory.appendingPathComponent("mods").standardizedFileURL.path))
        XCTAssertTrue(selectedPaths.contains(tempDirectory.appendingPathComponent("config").standardizedFileURL.path))
        XCTAssertTrue(selectedPaths.contains(tempDirectory.appendingPathComponent("options.txt").standardizedFileURL.path))
        XCTAssertFalse(selectedPaths.contains { $0.hasSuffix("example.jar") })
    }

    func testExpandingSelectedDirectoryInheritsSelection() throws {
        try makeFile("mods/sub/example.jar")

        let viewModel = FileTreeViewModel(rootURL: tempDirectory, showHiddenFiles: false)
        viewModel.applyDefaultSelectionIfNeeded()
        let mods = try XCTUnwrap(child(named: "mods", of: viewModel.root))

        viewModel.ensureChildrenLoaded(for: mods)
        let sub = try XCTUnwrap(child(named: "sub", of: mods))
        XCTAssertTrue(sub.selection == .all)
        XCTAssertNil(sub.children)

        viewModel.ensureChildrenLoaded(for: sub)
        let file = try XCTUnwrap(child(named: "example.jar", of: sub))
        XCTAssertTrue(file.selection == .all)
    }

    func testTogglingChildProducesPartialParentState() throws {
        try makeFile("mods/a.jar")
        try makeFile("mods/b.jar")

        let viewModel = FileTreeViewModel(rootURL: tempDirectory, showHiddenFiles: false)
        viewModel.ensureChildrenLoaded(for: viewModel.root)
        let mods = try XCTUnwrap(child(named: "mods", of: viewModel.root))
        viewModel.ensureChildrenLoaded(for: mods)
        let fileA = try XCTUnwrap(child(named: "a.jar", of: mods))

        viewModel.toggleSelection(for: fileA)

        XCTAssertTrue(fileA.selection == .all)
        XCTAssertTrue(mods.selection == .some)
        XCTAssertTrue(viewModel.root.selection == .some)
    }

    func testTogglingDirectoryDoesNotLoadChildren() throws {
        try makeFile("mods/sub/example.jar")

        let viewModel = FileTreeViewModel(rootURL: tempDirectory, showHiddenFiles: false)
        viewModel.ensureChildrenLoaded(for: viewModel.root)
        let mods = try XCTUnwrap(child(named: "mods", of: viewModel.root))

        viewModel.toggleSelection(for: mods)

        XCTAssertTrue(mods.selection == .all)
        XCTAssertNil(mods.children)
        XCTAssertEqual(
            viewModel.selectedRootURLs().map(\.lastPathComponent),
            ["mods"],
        )
    }

    func testSelectedRootURLsIncludesFilesAndDirectories() throws {
        try makeFile("mods/a.jar")
        try makeFile("config/config.json")
        try makeFile("options.txt")

        let viewModel = FileTreeViewModel(rootURL: tempDirectory, showHiddenFiles: false)
        viewModel.ensureChildrenLoaded(for: viewModel.root)
        let mods = try XCTUnwrap(child(named: "mods", of: viewModel.root))
        let options = try XCTUnwrap(child(named: "options.txt", of: viewModel.root))

        viewModel.toggleSelection(for: mods)
        viewModel.toggleSelection(for: options)

        XCTAssertEqual(
            Set(viewModel.selectedRootURLs().map(\.lastPathComponent)),
            Set(["mods", "options.txt"]),
        )
    }

    func testPartiallySelectedDirectoryReturnsOnlySelectedChildren() throws {
        try makeFile("mods/a.jar")
        try makeFile("mods/b.jar")

        let viewModel = FileTreeViewModel(rootURL: tempDirectory, showHiddenFiles: false)
        viewModel.ensureChildrenLoaded(for: viewModel.root)
        let mods = try XCTUnwrap(child(named: "mods", of: viewModel.root))
        viewModel.ensureChildrenLoaded(for: mods)
        let fileA = try XCTUnwrap(child(named: "a.jar", of: mods))

        viewModel.toggleSelection(for: fileA)

        XCTAssertEqual(
            viewModel.selectedRootURLs().map(\.lastPathComponent),
            ["a.jar"],
        )
    }

    private func child(named name: String, of node: FileNode) -> FileNode? {
        node.children?.first { $0.url.lastPathComponent == name }
    }

    private func makeFile(_ relativePath: String) throws {
        let fileURL = tempDirectory.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        try Data().write(to: fileURL)
    }
}
