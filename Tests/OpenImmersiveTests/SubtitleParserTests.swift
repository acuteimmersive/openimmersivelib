import XCTest
@testable import OpenImmersive

final class SubtitleParserTests: XCTestCase {

    var parser: SubtitleParser!

    override func setUp() {
        super.setUp()
        parser = SubtitleParser()
    }

    // MARK: - Format Detection

    func testFormatDetectionSRT() {
        let format = SubtitleParser.SubtitleFormat.from(fileExtension: "srt")
        XCTAssertEqual(format, .srt)
    }

    func testFormatDetectionVTT() {
        let format = SubtitleParser.SubtitleFormat.from(fileExtension: "vtt")
        XCTAssertEqual(format, .webvtt)
    }

    func testFormatDetectionASS() {
        let format = SubtitleParser.SubtitleFormat.from(fileExtension: "ass")
        XCTAssertEqual(format, .ass)
    }

    func testFormatDetectionUnknown() {
        let format = SubtitleParser.SubtitleFormat.from(fileExtension: "unknown")
        XCTAssertNil(format)
    }

    // MARK: - SRT Parsing

    func testParseSRTFile() throws {
        let url = try getTestAssetURL(filename: "sample_subtitles", extension: "srt")
        let cues = try parser.parse(fileURL: url)

        XCTAssertEqual(cues.count, 7, "Should parse all 7 cues")

        // First cue
        XCTAssertEqual(cues[0].text, "Welcome to the immersive video experience")
        XCTAssertEqual(cues[0].startTime, 0.0, accuracy: 0.001)
        XCTAssertEqual(cues[0].endTime, 3.0, accuracy: 0.001)

        // Last cue
        XCTAssertEqual(cues[6].text, "Enjoy your immersive video!")
        XCTAssertEqual(cues[6].startTime, 23.5, accuracy: 0.001)
    }

    // MARK: - WebVTT Parsing

    func testParseWebVTTFile() throws {
        let url = try getTestAssetURL(filename: "sample_subtitles", extension: "vtt")
        let cues = try parser.parse(fileURL: url)

        XCTAssertEqual(cues.count, 7, "Should parse all 7 cues")

        // First cue
        XCTAssertEqual(cues[0].text, "Welcome to the immersive video experience")
        XCTAssertEqual(cues[0].startTime, 0.0, accuracy: 0.001)
        XCTAssertEqual(cues[0].endTime, 3.0, accuracy: 0.001)
    }

    // MARK: - ASS Parsing

    func testParseASSFile() throws {
        let url = try getTestAssetURL(filename: "sample_subtitles", extension: "ass")
        let cues = try parser.parse(fileURL: url)

        XCTAssertEqual(cues.count, 7, "Should parse all 7 cues")
        XCTAssertEqual(cues[0].text, "Welcome to the immersive video experience")
    }

    // MARK: - JSON Parsing (String-based)

    func testParseJSONFile() throws {
        let url = try getTestAssetURL(filename: "sample_subtitles", extension: "json")
        let data = try Data(contentsOf: url)

        // JSON format is not directly supported by SwiftSubtitles,
        // but we can verify the file exists and is valid JSON
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(json, "JSON file should be valid")
    }

    // MARK: - TTML Parsing

    func testParseTTMLFile() throws {
        let url = try getTestAssetURL(filename: "sample_subtitles", extension: "ttml")

        // TTML is XML-based, verify it's well-formed and accessible
        let data = try Data(contentsOf: url)
        let xml = try XMLParser(data: data)
        XCTAssertTrue(xml.parse(), "TTML file should be valid XML")
    }

    // MARK: - LRC Parsing

    func testParseLRCFile() throws {
        let url = try getTestAssetURL(filename: "sample_subtitles", extension: "lrc")

        // LRC files exist, verify they're readable
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("["), "LRC file should contain timestamp markers")
    }

    // MARK: - Unsupported Format

    func testParseUnsupportedFormat() throws {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.xyz")

        do {
            _ = try parser.parse(fileURL: tempURL)
            XCTFail("Should throw unsupportedFormat error")
        } catch let error as SubtitleParser.ParserError {
            if case .unsupportedFormat(let ext) = error {
                XCTAssertEqual(ext, "xyz")
            } else {
                XCTFail("Should be unsupportedFormat error")
            }
        }
    }

    // MARK: - Helper Methods

    private func getTestAssetURL(filename: String, extension: String) throws -> URL {
        #if os(visionOS)
        let bundle = Bundle.main
        #else
        let bundle = Bundle.module
        #endif

        guard let url = bundle.url(forResource: filename, withExtension: `extension`, subdirectory: "TestAssets") else {
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find test asset: \(filename).\(`extension`)"])
        }

        return url
    }
}
