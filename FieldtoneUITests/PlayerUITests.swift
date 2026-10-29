import Foundation
import XCTest

final class PlayerUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    private func expect(_ title: String, playing: Bool, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(app.staticTexts["trackTitle"].label, title, file: file, line: line)
        XCTAssertEqual(app.buttons["playPause"].label, playing ? "Пауза" : "Воспроизвести", file: file, line: line)
    }

    func testTransportAndWrapAround() {
        expect("Soft Focus", playing: false)
        app.buttons["previous"].tap()
        expect("Night Ferry", playing: false)
        app.buttons["playPause"].tap()
        expect("Night Ferry", playing: true)
        app.buttons["next"].tap()
        expect("Soft Focus", playing: true)
        app.buttons["next"].tap()
        expect("Tidal Glass", playing: true)
        app.buttons["playPause"].tap()
        app.buttons["previous"].tap()
        expect("Soft Focus", playing: false)
    }

    func testAutoAdvance() {
        app.buttons["playPause"].tap()
        let title = app.staticTexts["trackTitle"]
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Tidal Glass"), object: title
        )
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 32), .completed)
        expect("Tidal Glass", playing: true)
    }

    // Scripts/capture.sh handshakes with the test runner through its own data container.
    func testRecordDemo() throws {
        guard ProcessInfo.processInfo.environment["FIELDTONE_CAPTURE"] == "1" else {
            throw XCTSkip("Запускается скриптом capture.sh во время записи экрана.")
        }

        expect("Soft Focus", playing: false)
        let dir = FileManager.default.temporaryDirectory
        let ready = dir.appendingPathComponent("fieldtone-ready")
        let go = dir.appendingPathComponent("fieldtone-go")
        let done = dir.appendingPathComponent("fieldtone-done")
        try Data().write(to: ready)
        let deadline = Date().addingTimeInterval(45)
        while !FileManager.default.fileExists(atPath: go.path) && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: go.path), "Рекордер не запустился.")
        let start = Date()
        func at(_ seconds: TimeInterval, _ action: () -> Void) {
            let remaining = start.addingTimeInterval(seconds).timeIntervalSinceNow
            if remaining > 0 { Thread.sleep(forTimeInterval: remaining) }
            action()
        }
        at(1)    { app.buttons["playPause"].tap(); expect("Soft Focus", playing: true) }
        at(5)    { app.buttons["playPause"].tap(); expect("Soft Focus", playing: false) }
        at(7.5)  { app.buttons["previous"].tap(); expect("Night Ferry", playing: false) }
        at(10)   { app.buttons["playPause"].tap(); expect("Night Ferry", playing: true) }
        at(13.5) { app.buttons["next"].tap(); expect("Soft Focus", playing: true) }
        at(17)   { app.buttons["next"].tap(); expect("Tidal Glass", playing: true) }
        at(20.5) { app.buttons["previous"].tap(); expect("Soft Focus", playing: true) }
        at(23)   { app.buttons["playPause"].tap(); expect("Soft Focus", playing: false) }
        at(24)   {}
        try Data().write(to: done)
        // Keep the last frame on screen while simctl finishes the recording.
        Thread.sleep(forTimeInterval: 1)
    }
}
