import XCTest
@testable import SuspensionKit

final class RideToolsTests: XCTestCase {
    let catalog = Catalog.bundled
    func rec(_ id: String, travel: Double, stroke: Double = 0) -> Recommendation {
        let m = catalog.models.first { $0.id == id }!
        return SuspensionEngine.calculate(model: m, rider: RiderInput(weightKg: 84, heightCm: 180, frameSize: .L,
                                                                     style: .trail, travelMm: travel, strokeMm: stroke))   // trail = maker's baseline
    }

    func testBottomingOutAddsSpacerFirst() {
        let r = rec("fox-36-factory", travel: 150)                       // 89 psi, 2 tokens, HSC 5 out
        let fixes = Troubleshooter.fixes(for: .bottomsOut, rec: r, ran: RanSetup(), kind: .fork)
        XCTAssertEqual(fixes.map(\.change), [.tokens(3), .clicks(key: "hsc", value: 3), .spring(94)])
        XCTAssertEqual(fixes[1].title, "HSC: 5 → 3 clicks out (2 firmer)")   // FOX counts out from closed
    }

    func testRockShoxCompressionCountsIn() {
        let r = rec("rockshox-lyrik-ultimate", travel: 160)              // LSC 3 in of 5
        let fix = Troubleshooter.fixes(for: .divesUnderBraking, rec: r, ran: RanSetup(), kind: .fork).first!
        XCTAssertEqual(fix.change, .clicks(key: "lsc", value: 5))
        XCTAssertTrue(fix.title.contains("clicks in"))
    }

    func testFixesStartFromWhatWasRun() {
        let r = rec("fox-36-factory", travel: 150)
        let ran = RanSetup(springValue: 95, clicks: ["lsr": 8])
        let fixes = Troubleshooter.fixes(for: .kicksOnJumps, rec: r, ran: ran, kind: .fork)
        XCTAssertEqual(fixes.first?.change, .clicks(key: "lsr", value: 6))
        let applied = Troubleshooter.apply(fixes[0], to: ran, rec: r)
        XCTAssertNil(applied.clicks["lsr"])                               // 6 = recommended → back to "as recommended"
        XCTAssertEqual(applied.springValue, 95)
    }

    func testSymptomsFilteredByEnd() {
        XCTAssertFalse(Symptom.divesUnderBraking.applies(to: .shock))
        XCTAssertFalse(Symptom.bobsPedalling.applies(to: .fork))
    }

    func testSagCheck() {
        let r = rec("fox-36-factory", travel: 150)                       // 15–20% of 150 mm
        XCTAssertEqual(SagCheck.evaluate(measuredMm: 27, lengthMm: 150, rec: r, springValue: 89).status, .good)
        let soft = SagCheck.evaluate(measuredMm: 36, lengthMm: 150, rec: r, springValue: 89)   // 24%
        XCTAssertEqual(soft.status, .tooMuch)
        XCTAssertEqual(soft.suggestedSpring, 103)                         // 89 × √(24/18)
        XCTAssertEqual(SagCheck.evaluate(measuredMm: 15, lengthMm: 150, rec: r, springValue: 89).status, .tooLittle)
    }

    func testCoilSpringSizes() {
        let opts = CoilSprings.options(rate: 450, targetSag: 30)
        XCTAssertEqual(opts.map(\.rate), [400, 425, 450, 475, 500])
        XCTAssertEqual(opts[3].sagPercent, 30 * 450 / 475, accuracy: 0.001)
        XCTAssertEqual(CoilSprings.label(rate: 450, strokeMm: 62.5), "450 × 2.5″")
        XCTAssertEqual(CoilSprings.label(rate: 450, strokeMm: 65), "450 × 2.75″")
        XCTAssertEqual(CoilSprings.label(rate: 450, strokeMm: 75), "450 × 3.0″")
    }

    func testChecklistUsesTheBikesNumbers() {
        let items = PreRideChecklist.items(fork: rec("fox-36-factory", travel: 150), shock: nil)
        XCTAssertEqual(items.first?.title, "Fork at 89 psi")
        XCTAssertEqual(items.first { $0.id == "tires" }?.title, "Tires: 22 psi front")
    }
}
