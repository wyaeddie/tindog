import XCTest
@testable import SuspensionKit

/// Same golden values as python/test_engine.py — keeps both engines in lockstep.
final class EngineTests: XCTestCase {
    let catalog = Catalog.bundled
    func model(_ id: String) -> SuspensionModel { catalog.models.first { $0.id == id }! }
    func rider(_ style: RidingStyle, _ travel: Double, _ stroke: Double = 0) -> RiderInput {
        RiderInput(weightKg: 84, heightCm: 180, frameSize: .L, style: style, travelMm: travel, strokeMm: stroke)
    }

    // 84 kg = 185 lb → the FOX 36 chart's 180–190 lb row
    func testFox36ReadsFoxChart() {
        let r = SuspensionEngine.calculate(model: model("fox-36-factory"), rider: rider(.enduro, 150))
        XCTAssertEqual(r.headlineValue, "89")
        XCTAssertEqual(r.quality, .manufacturer)
        XCTAssertEqual(r.value("Sag"), "18%  ·  27.0 mm")
        XCTAssertEqual([r.sagMin, r.sagMax], [15, 20])
        XCTAssertEqual(r.value("Volume spacers"), "2 tokens")
        XCTAssertEqual(r.tokenMax, 7)
        XCTAssertEqual(r.value("Low-speed rebound"), "6 clicks out")
        XCTAssertEqual(r.value("High-speed rebound"), "4 clicks out")
        XCTAssertEqual(r.value("Low-speed compression"), "10 clicks out")
        XCTAssertEqual(r.value("High-speed compression"), "5 clicks out")
        XCTAssertTrue(r.clicks.allSatisfy { $0.fromClosed && $0.isManufacturer })
    }

    func testLyrikReadsSramChart() {
        let r = SuspensionEngine.calculate(model: model("rockshox-lyrik-ultimate"), rider: rider(.trail, 160))
        XCTAssertEqual(r.headlineValue, "83")          // 180–200 lb band: 80–90 psi
        XCTAssertEqual(r.value("Volume spacers"), "0 tokens")
        XCTAssertEqual(r.value("Low-speed compression"), "3 clicks in")
        XCTAssertEqual(r.quality, .partial)            // rebound isn't published (TrailHead app only)
        XCTAssertEqual(r.clicks.first { $0.key == "rebound" }?.isManufacturer, false)
    }

    func testZebPicksTableForTravel() {
        XCTAssertEqual(SuspensionEngine.calculate(model: model("rockshox-zeb-ultimate"), rider: rider(.enduro, 190)).headlineValue, "56")
        XCTAssertEqual(SuspensionEngine.calculate(model: model("rockshox-zeb-ultimate"), rider: rider(.enduro, 160)).headlineValue, "72")
    }

    func testFloatX2BodyWeightAndPsiTable() {
        let r = SuspensionEngine.calculate(model: model("fox-float-x2-factory"), rider: rider(.trail, 160, 62.5))
        XCTAssertEqual(r.headlineValue, "185")
        XCTAssertEqual(r.value("Low-speed rebound"), "8 clicks out")
        XCTAssertEqual(r.value("Low-speed compression"), "9–10 clicks out")
        XCTAssertEqual(r.clicks.first { $0.key == "lsc" }?.value, 10)
    }

    func testDhx2CoilRateAndRateTable() {
        let r = SuspensionEngine.calculate(model: model("fox-dhx2-factory"), rider: rider(.park, 160, 62.5))
        XCTAssertEqual(r.headlineValue, "475")
        XCTAssertEqual(r.value("Low-speed rebound"), "8 clicks out")
    }

    func testKitsumaCoilEstimate() {
        let r = SuspensionEngine.calculate(model: model("cane-creek-kitsuma-coil"), rider: rider(.park, 170, 65))
        XCTAssertEqual(r.headlineValue, "450")
        XCTAssertEqual(r.headlineUnit, "lb/in")
        XCTAssertEqual(r.quality, .estimate)
    }

    func testOutsideChartWarns() {
        let r = SuspensionEngine.calculate(model: model("fox-38-factory"),
            rider: RiderInput(weightKg: 180, heightCm: 200, frameSize: .XL, style: .trail, travelMm: 170))
        XCTAssertEqual(r.headlineValue, "123")         // last row of the FOX 38 chart
        XCTAssertTrue(r.warnings.contains { $0.contains("outside Fox's chart") })
    }

    func testPressureCappedAtMax() {
        let r = SuspensionEngine.calculate(model: model("dvo-onyx-sc-d1"),
            rider: RiderInput(weightKg: 180, heightCm: 200, frameSize: .XL, style: .trail, travelMm: 170))
        XCTAssertEqual(r.headlineValue, "140")
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

    func testSpecsURLs() {
        XCTAssertEqual(catalog.specsURL(for: model("fox-36-factory"))?.absoluteString, "https://ridefox.com/pages/fox-36")
        XCTAssertEqual(catalog.specsURL(for: model("dvo-topaz-t3-air"))?.absoluteString,
                       "https://www.google.com/search?q=site:dvosuspension.com%20Topaz%20T3%20Air%20specs")
        for m in catalog.models { XCTAssertNotNil(catalog.specsURL(for: m), m.id) }
    }
}
