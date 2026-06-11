import XCTest
@testable import SwiftCraftLauncher

final class AnnouncementModelsTests: XCTestCase {

    // MARK: - AnnouncementResponse

    func testAnnouncementResponse_init() {
        let response = AnnouncementResponse(
            success: true,
            data: AnnouncementData(title: "Title", content: "Content", author: "Author")
        )

        XCTAssertTrue(response.success)
        XCTAssertNotNil(response.data)
        XCTAssertEqual(response.data?.title, "Title")
        XCTAssertEqual(response.data?.content, "Content")
        XCTAssertEqual(response.data?.author, "Author")
    }

    func testAnnouncementResponse_nilData() {
        let response = AnnouncementResponse(success: false, data: nil)

        XCTAssertFalse(response.success)
        XCTAssertNil(response.data)
    }

    func testAnnouncementResponse_codable_roundTrip() throws {
        let original = AnnouncementResponse(
            success: true,
            data: AnnouncementData(title: "Update", content: "New features", author: "Dev")
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnnouncementResponse.self, from: data)

        XCTAssertTrue(decoded.success)
        XCTAssertEqual(decoded.data?.title, "Update")
        XCTAssertEqual(decoded.data?.content, "New features")
        XCTAssertEqual(decoded.data?.author, "Dev")
    }

    func testAnnouncementResponse_codable_fromJSON() throws {
        let json = """
        {"success": true, "data": {"title": "T", "content": "C", "author": "A"}}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnnouncementResponse.self, from: data)

        XCTAssertTrue(decoded.success)
        XCTAssertEqual(decoded.data?.title, "T")
    }

    // MARK: - AnnouncementData

    func testAnnouncementData_codable_roundTrip() throws {
        let original = AnnouncementData(
            title: "Patch Notes",
            content: "Bug fixes and improvements",
            author: "Team"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnnouncementData.self, from: data)

        XCTAssertEqual(decoded.title, "Patch Notes")
        XCTAssertEqual(decoded.content, "Bug fixes and improvements")
        XCTAssertEqual(decoded.author, "Team")
    }
}
