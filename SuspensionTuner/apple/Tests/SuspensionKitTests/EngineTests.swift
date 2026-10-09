import XCTest
@testable import SuspensionKit

/// Same golden values as python/test_engine.py — keeps both engines in lockstep.
final class EngineTests: XCTestCase {
    let catalog = Catalog.bundled
    func model(_ id: String) -> SuspensionModel { catalog.models.first { $0.id == id }! }
    func rider(_ style: RidingStyle, _ travel: Double, _ stroke: Double = 0) -> RiderInput {
        RiderInput(weightKg: 84, heightCm: 180, frameSize: .L, style: style, travelMm: travel, strokeMm: stroke)
    }

    func testFox36Enduro() {
        let r = SuspensionEngine.calculate(model: model("fox-36-factory"), rider: rider(.enduro, 150))
        XCTAssertEqual(r.headlineValue, "88")
        XCTAssertEqual(r.value("Sag"), "22%  ·  33.0 mm")
        XCTAssertEqual(r.value("Volume spacers"), "3 tokens")
        XCTAssertEqual(r.value("Low-speed compression"), "7 clicks in")
    }

    func testKitsumaCoilPark() {
        let r = SuspensionEngine.calculate(model: model("cane-creek-kitsuma-coil"), rider: rider(.park, 170, 65))
        XCTAssertEqual(r.headlineValue, "450")
        XCTAssertEqual(r.headlineUnit, "lb/in")
    }

    func testFloatX2Trail() {
        let r = SuspensionEngine.calculate(model: model("fox-float-x2-factory"), rider: rider(.trail, 160, 62.5))
        XCTAssertEqual(r.headlineValue, "174")
    }

    func testPressureCappedAtMax() {
        let r = SuspensionEngine.calculate(model: model("fox-38-factory"),
            rider: RiderInput(weightKg: 180, heightCm: 200, frameSize: .XL, style: .trail, travelMm: 170))
        XCTAssertEqual(r.headlineValue, "120")
        XCTAssertTrue(r.warnings.contains { $0.contains("exceeds") })
    }

    func testXCForkInParkWarns() {
        let r = SuspensionEngine.calculate(model: model("rockshox-sid-sl-ultimate"), rider: rider(.park, 100))
        XCTAssertTrue(r.warnings.contains { $0.contains("XC product") })
    }

    func testFrameSizeFromHeight() {
        XCTAssertEqual([155, 170, 180, 195].map { SuspensionEngine.recommendedFrameSize(heightCm: $0) },
                       [.S, .M, .L, .XL])
    }

    func testEveryModelCalculates() {
        XCTAssertEqual(catalog.models.count, 65)
        for m in catalog.models {
            let r = SuspensionEngine.calculate(model: m, rider: rider(.enduro, m.travel.default, m.stroke?.default ?? 0))
            XCTAssertGreaterThan(Int(r.headlineValue) ?? 0, 0, m.id)
        }
    }
}
