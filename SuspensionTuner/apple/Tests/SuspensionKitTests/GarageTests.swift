import XCTest
@testable import SuspensionKit

final class GarageTests: XCTestCase {
    let catalog = Catalog.bundled

    func makeBike() -> Bike {
        Bike(name: "Enduro Rig",
             rider: RiderProfile(weightLb: 84 * 2.20462, heightIn: 180 / 2.54, frameSize: .L),
             style: .enduro,
             fork: SuspensionSlot(modelID: "fox-36-factory", travelMm: 150),
             shock: SuspensionSlot(modelID: "fox-float-x2-factory", travelMm: 160, strokeMm: 62.5))
    }

    func testBikeRecommendationMatchesDirectCalculation() {
        let bike = makeBike()
        let rec = catalog.recommendation(for: bike, end: .fork)!
        XCTAssertEqual(rec.headlineValue, "89")          // same golden value as EngineTests
        XCTAssertEqual(rec.springValue, 89)
        XCTAssertTrue(rec.isAir)
        XCTAssertEqual(rec.sagPercent, 18)
        XCTAssertEqual(rec.tokens, 2)
        XCTAssertEqual(rec.clicks.map(\.short), ["LSR", "HSR", "LSC", "HSC"])
        XCTAssertEqual(rec.clicks.first { $0.key == "lsc" }?.value, 10)
        XCTAssertEqual(bike.ends, [.fork, .shock])
        XCTAssertNotNil(catalog.recommendation(for: bike, end: .shock))
    }

    func testCoilHasSpringRateAndNoTokens() {
        var bike = makeBike()
        bike.style = .park
        bike.rider.frameSize = .L
        bike.shock = SuspensionSlot(modelID: "cane-creek-kitsuma-coil", travelMm: 170, strokeMm: 65)
        let rec = catalog.recommendation(for: bike, end: .shock)!
        XCTAssertFalse(rec.isAir)
        XCTAssertEqual(rec.headlineUnit, "lb/in")
        XCTAssertEqual(rec.springValue, Int(rec.headlineValue))
        XCTAssertNil(rec.tokens)
        XCTAssertNil(rec.maxPsi)
    }

    func testDifferences() {
        let rec = catalog.recommendation(for: makeBike(), end: .fork)!
        XCTAssertEqual(rec.differences(from: RanSetup()), [])
        let ran = RanSetup(springValue: 92, tokens: 2, clicks: ["lsc": 8, "lsr": 6])
        XCTAssertEqual(rec.differences(from: ran),
                       ["Air pressure: 92 psi (recommended 89)", "Low-speed compression: 8 clicks out (recommended 10)"])
    }

    func testRoundTripJSON() throws {
        var bike = makeBike()
        bike.setRan(RanSetup(springValue: 86, clicks: ["lsr": 6]), for: .fork)
        let entry = HistoryEntry(date: Date(timeIntervalSince1970: 1_790_000_000), bikeID: bike.id,
                                 bikeName: bike.name, end: .fork, brand: "Fox", modelName: "36 Factory",
                                 style: .enduro, recommended: ["Air pressure: 89 psi"], ran: [], note: "felt great")
        let data = GarageData(bikes: [bike], selectedBikeID: bike.id, history: [entry], useKilograms: true)
        let back = try GarageData.decode(data.encoded())
        XCTAssertEqual(back, data)
        XCTAssertEqual(back.selectedBike?.ran(.fork).springValue, 86)
        XCTAssertEqual(back.selectedBike?.rider.heightText, "5′11″")
    }

    func testGarageSavedByOlderVersionStillLoads() throws {
        let old = """
        {"bikes":[{"id":"6B1F4E1A-1C7B-4C1E-9C55-0F0B8A5D1E01","name":"Old Rig",
          "rider":{"weightLb":185,"heightIn":71,"frameSize":"L"},"style":"enduro",
          "fork":{"modelID":"fox-36-factory","travelMm":150,"strokeMm":0},
          "forkRan":{"clicks":{}},"shockRan":{"clicks":{}}}],
         "history":[],"useKilograms":false}
        """
        let data = try GarageData.decode(Data(old.utf8))
        let bike = try XCTUnwrap(data.bikes.first)
        XCTAssertEqual(bike.setup, BikeSetup())
        XCTAssertEqual(bike.ride, RideConditions())
        XCTAssertEqual(bike.rider.skill, .intermediate)
        XCTAssertEqual(catalog.recommendation(for: bike, end: .fork)?.headlineValue, "89")
    }

    func testSelectedBikeFallsBackToFirst() {
        let bike = makeBike()
        XCTAssertEqual(GarageData(bikes: [bike], selectedBikeID: UUID()).selectedBike?.id, bike.id)
        XCTAssertNil(GarageData().selectedBike)
    }
}
