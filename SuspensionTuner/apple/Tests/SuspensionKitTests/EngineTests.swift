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
        let r = SuspensionEngine.calculate(model: model("fox-36-factory"), rider: rider(.trail, 150))   // trail = maker's baseline
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
        XCTAssertEqual(r.value("Low-speed rebound"), "7 clicks out")   // chart 8, 1 slower for bike park
    }

    func testKitsumaCoilEstimate() {
        let r = SuspensionEngine.calculate(model: model("cane-creek-kitsuma-coil"), rider: rider(.park, 170, 65))
        XCTAssertEqual(r.headlineValue, "450")
        XCTAssertEqual(r.headlineUnit, "lb/in")
        XCTAssertEqual(r.quality, .partial)            // Cane Creek publishes sag (25–35%), not a spring chart
    }

    func testOutsideChartWarns() {
        let r = SuspensionEngine.calculate(model: model("fox-38-factory"),
            rider: RiderInput(weightKg: 180, heightCm: 200, frameSize: .XL, style: .trail, travelMm: 170))
        XCTAssertEqual(r.headlineValue, "123")         // last row of the FOX 38 chart
        XCTAssertTrue(r.warnings.contains { $0.contains("outside Fox's chart") })
    }

    func testPressureCappedAtMax() {
        let r = SuspensionEngine.calculate(model: model("ohlins-rxc34-m1"),     // no published chart → estimate
            rider: RiderInput(weightKg: 180, heightCm: 200, frameSize: .XL, style: .trail, travelMm: 110))
        XCTAssertEqual(r.headlineValue, "170")
        XCTAssertEqual(r.quality, .estimate)
        XCTAssertTrue(r.warnings.contains { $0.contains("exceeds") })
    }

    // MARK: Ride, rider and bike factors

    func testEBikeUsesFoxEBikeChart() {
        var r = rider(.enduro, 150)
        r.bike.eBike = true
        let rec = SuspensionEngine.calculate(model: model("fox-36-factory"), rider: r)
        XCTAssertEqual(rec.headlineValue, "99")            // 36 E-Bike+ chart, 180–190 lb row
        XCTAssertEqual(rec.value("Volume spacers"), "4 tokens")
        XCTAssertEqual(rec.value("Low-speed rebound"), "5 clicks out")   // 1 slower for the heavier bike
    }

    func testEBikeAddsTenPsiOnRockShox() {
        var r = rider(.trail, 160)
        r.bike.eBike = true
        XCTAssertEqual(SuspensionEngine.calculate(model: model("rockshox-lyrik-ultimate"), rider: r).headlineValue, "93")
    }

    func testPackReadsHeavierRow() {
        var r = rider(.enduro, 150)
        r.ride.pack = .day                                  // 185 + 12 = 197 lb → 190–200 row
        XCTAssertEqual(SuspensionEngine.calculate(model: model("fox-36-factory"), rider: r).headlineValue, "94")
    }

    func testFeelPicksEndOfSagRange() {
        var r = rider(.enduro, 150)
        r.ride.feel = .firm
        let firm = SuspensionEngine.calculate(model: model("fox-36-factory"), rider: r)
        XCTAssertEqual(firm.sagPercent, 15)
        XCTAssertEqual(firm.headlineValue, "96")            // 89 × √(17.5 / 15)
        r.ride.feel = .plush
        XCTAssertEqual(SuspensionEngine.calculate(model: model("fox-36-factory"), rider: r).sagPercent, 20)
    }

    func testColdTrailMeansPumpMoreIndoors() {
        var r = rider(.enduro, 150)
        r.ride.temperatureF = 40
        let rec = SuspensionEngine.calculate(model: model("fox-36-factory"), rider: r)
        XCTAssertEqual(rec.trailPsi, 89)
        XCTAssertEqual(rec.headlineValue, "95")
    }

    func testTerrainAndSkillNudgeClicks() {
        var r = rider(.trail, 150)
        r.ride.terrain = .rough
        var rec = SuspensionEngine.calculate(model: model("fox-36-factory"), rider: r)
        XCTAssertEqual(rec.value("Low-speed rebound"), "7 clicks out")       // 1 faster
        XCTAssertEqual(rec.value("High-speed compression"), "6 clicks out")  // 1 softer
        r.ride.terrain = .mixed
        r.skill = .aggressive
        rec = SuspensionEngine.calculate(model: model("fox-36-factory"), rider: r)
        XCTAssertEqual(rec.value("Low-speed compression"), "9 clicks out")   // 1 firmer
        XCTAssertEqual(rec.value("Volume spacers"), "3 tokens")
        r.skill = .intermediate
        r.ride.priority = .climb
        rec = SuspensionEngine.calculate(model: model("rockshox-lyrik-ultimate"), rider: r)
        XCTAssertEqual(rec.value("Low-speed compression"), "4 clicks in")    // counted in from open: firmer = more
    }

    func testForwardPositionAddsFrontPressure() {
        var r = rider(.enduro, 150)
        r.position = .forward
        XCTAssertEqual(SuspensionEngine.calculate(model: model("fox-36-factory"), rider: r).headlineValue, "93")
    }

    func testFrameSagOverridesShockSag() {
        var r = rider(.trail, 160, 62.5)
        r.bike.frameRearSag = 32
        let rec = SuspensionEngine.calculate(model: model("fox-float-x2-factory"), rider: r)
        XCTAssertEqual(rec.sagPercent, 32)
        XCTAssertEqual(rec.headlineValue, "172")           // 185.2 × √(27.5 / 32) = 171.7
    }

    func testTirePressureAndService() {
        var r = rider(.enduro, 150)
        XCTAssertEqual(SuspensionEngine.calculate(model: model("fox-36-factory"), rider: r).value("Tire pressure"), "22 psi front")
        r.bike.inserts = true
        r.bike.tireWidth = .wide
        r.bike.forkHours = 130
        let rec = SuspensionEngine.calculate(model: model("fox-36-factory"), rider: r)
        XCTAssertEqual(rec.tirePsi, 18)
        XCTAssertTrue(rec.serviceDue)
        r.bike.forkHours = 60
        XCTAssertTrue(SuspensionEngine.calculate(model: model("rockshox-lyrik-ultimate"), rider: r).serviceDue)  // 50 h lowers
    }

    func testRidingStyleAdjustsMakerBaseline() {
        func fox(_ s: RidingStyle) -> Recommendation {
            SuspensionEngine.calculate(model: model("fox-36-factory"), rider: rider(s, 150))
        }
        XCTAssertEqual(fox(.enduro).value("High-speed compression"), "4 clicks out")
        let park = fox(.park)
        XCTAssertEqual(park.value("High-speed compression"), "3 clicks out")
        XCTAssertEqual(park.value("Low-speed compression"), "9 clicks out")
        XCTAssertEqual(park.value("Low-speed rebound"), "5 clicks out")
        XCTAssertEqual(park.tokens, 3)
        let dh = fox(.dh)
        XCTAssertEqual([dh.sagPercent, Int(dh.headlineValue)!], [20, 83])
        XCTAssertEqual(dh.value("Low-speed rebound"), "7 clicks out")
        let xc = fox(.xc)
        XCTAssertEqual([xc.sagPercent, Int(xc.headlineValue)!], [15, 96])
        XCTAssertEqual(xc.value("Low-speed compression"), "9 clicks out")
    }

    func testXCAndDownhillStyles() {
        XCTAssertEqual(SuspensionEngine.calculate(model: model("ext-aria"), rider: rider(.dh, 150, 57.5)).sagPercent, 33)
        XCTAssertFalse(SuspensionEngine.calculate(model: model("rockshox-sid-sl-ultimate"), rider: rider(.xc, 100))
            .warnings.contains { $0.contains("XC product") })
        XCTAssertTrue(SuspensionEngine.calculate(model: model("rockshox-sid-sl-ultimate"), rider: rider(.dh, 100))
            .warnings.contains { $0.contains("Downhill riding") })
    }

    func testFrameLeverageCurveMovesShockSpacers() {
        var r = rider(.trail, 160, 62.5)
        r.bike.frameProgression = .linear
        XCTAssertEqual(SuspensionEngine.calculate(model: model("fox-float-x2-factory"), rider: r).value("Volume spacers"), "2 tokens")
        r.bike.frameProgression = .progressive
        XCTAssertEqual(SuspensionEngine.calculate(model: model("fox-float-x2-factory"), rider: r).value("Volume spacers"), "0 tokens")
    }

    func testNewBrandCharts() {
        let mez = SuspensionEngine.calculate(model: model("manitou-mezzer-pro"), rider: rider(.enduro, 170))
        XCTAssertEqual(mez.headlineValue, "62")
        XCTAssertEqual(mez.value("IRT chamber"), "94 psi")
        XCTAssertEqual(mez.value("Rebound"), "6–7 clicks out")
        XCTAssertEqual(SuspensionEngine.calculate(model: model("cane-creek-helm-mkii-air"), rider: rider(.enduro, 160)).headlineValue, "65")
        XCTAssertEqual(SuspensionEngine.calculate(model: model("formula-selva-s"), rider: rider(.enduro, 170)).headlineValue, "79")
        XCTAssertEqual(SuspensionEngine.calculate(model: model("rockshox-super-deluxe-ultimate-air"), rider: rider(.enduro, 150, 60)).headlineValue, "196")
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
