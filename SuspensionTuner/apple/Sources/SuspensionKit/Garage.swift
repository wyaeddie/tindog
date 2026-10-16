import Foundation

// Saved bikes, what the rider actually ran, and setup history.
// Pure data (Codable) so it can be unit-tested and stored as JSON by the app.

public struct RiderProfile: Codable, Hashable {
    public var weightLb: Double
    /// Total height in inches (5′11″ = 71)
    public var heightIn: Double
    public var frameSize: FrameSize

    public init(weightLb: Double, heightIn: Double, frameSize: FrameSize) {
        self.weightLb = weightLb; self.heightIn = heightIn; self.frameSize = frameSize
    }

    public var weightKg: Double { weightLb / 2.20462 }
    public var heightCm: Double { heightIn * 2.54 }
    public var heightText: String {
        let total = Int(heightIn.rounded())
        return "\(total / 12)′\(total % 12)″"
    }
}

/// A fork or shock fitted to a bike.
public struct SuspensionSlot: Codable, Hashable {
    public var modelID: String
    /// Fork travel, or rear-wheel travel for a shock
    public var travelMm: Double
    /// Shock stroke (0 for forks)
    public var strokeMm: Double

    public init(modelID: String, travelMm: Double, strokeMm: Double = 0) {
        self.modelID = modelID; self.travelMm = travelMm; self.strokeMm = strokeMm
    }
}

/// What the rider actually set. A nil / missing value means "following the recommendation".
public struct RanSetup: Codable, Hashable {
    public var springValue: Int?
    public var tokens: Int?
    public var clicks: [String: Int]

    public init(springValue: Int? = nil, tokens: Int? = nil, clicks: [String: Int] = [:]) {
        self.springValue = springValue; self.tokens = tokens; self.clicks = clicks
    }

    public var isEmpty: Bool { springValue == nil && tokens == nil && clicks.isEmpty }
}

public struct Bike: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var rider: RiderProfile
    public var style: RidingStyle
    public var fork: SuspensionSlot?
    public var shock: SuspensionSlot?
    public var forkRan: RanSetup
    public var shockRan: RanSetup

    public init(id: UUID = UUID(), name: String, rider: RiderProfile, style: RidingStyle = .trail,
                fork: SuspensionSlot? = nil, shock: SuspensionSlot? = nil,
                forkRan: RanSetup = RanSetup(), shockRan: RanSetup = RanSetup()) {
        self.id = id; self.name = name; self.rider = rider; self.style = style
        self.fork = fork; self.shock = shock; self.forkRan = forkRan; self.shockRan = shockRan
    }

    /// The ends this bike has, front first.
    public var ends: [ComponentKind] {
        var out: [ComponentKind] = []
        if fork != nil { out.append(.fork) }
        if shock != nil { out.append(.shock) }
        return out
    }

    public func slot(_ end: ComponentKind) -> SuspensionSlot? { end == .fork ? fork : shock }
    public func ran(_ end: ComponentKind) -> RanSetup { end == .fork ? forkRan : shockRan }

    public mutating func setRan(_ ran: RanSetup, for end: ComponentKind) {
        if end == .fork { forkRan = ran } else { shockRan = ran }
    }

    public func riderInput(for end: ComponentKind) -> RiderInput? {
        guard let slot = slot(end) else { return nil }
        return RiderInput(weightKg: rider.weightKg, heightCm: rider.heightCm, frameSize: rider.frameSize,
                          style: style, travelMm: slot.travelMm, strokeMm: slot.strokeMm)
    }
}

public struct HistoryEntry: Codable, Identifiable, Hashable {
    public var id: UUID
    public var date: Date
    public var bikeID: UUID
    public var bikeName: String
    public var end: ComponentKind
    public var brand: String
    public var modelName: String
    public var style: RidingStyle
    /// "Label: value" lines of the recommendation at the time
    public var recommended: [String]
    /// Lines describing what differed from the recommendation (empty = ran as recommended)
    public var ran: [String]
    public var note: String

    public init(id: UUID = UUID(), date: Date = Date(), bikeID: UUID, bikeName: String, end: ComponentKind,
                brand: String, modelName: String, style: RidingStyle,
                recommended: [String], ran: [String], note: String) {
        self.id = id; self.date = date; self.bikeID = bikeID; self.bikeName = bikeName; self.end = end
        self.brand = brand; self.modelName = modelName; self.style = style
        self.recommended = recommended; self.ran = ran; self.note = note
    }
}

public struct GarageData: Codable, Equatable {
    public var bikes: [Bike]
    public var selectedBikeID: UUID?
    public var history: [HistoryEntry]
    public var useKilograms: Bool

    public init(bikes: [Bike] = [], selectedBikeID: UUID? = nil, history: [HistoryEntry] = [], useKilograms: Bool = false) {
        self.bikes = bikes; self.selectedBikeID = selectedBikeID; self.history = history; self.useKilograms = useKilograms
    }

    public var selectedBike: Bike? {
        bikes.first { $0.id == selectedBikeID } ?? bikes.first
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> GarageData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GarageData.self, from: data)
    }
}

public extension Catalog {
    func model(id: String) -> SuspensionModel? { models.first { $0.id == id } }

    func model(for bike: Bike, end: ComponentKind) -> SuspensionModel? {
        bike.slot(end).flatMap { model(id: $0.modelID) }
    }

    func recommendation(for bike: Bike, end: ComponentKind) -> Recommendation? {
        guard let model = model(for: bike, end: end), let rider = bike.riderInput(for: end) else { return nil }
        return SuspensionEngine.calculate(model: model, rider: rider)
    }
}

public extension Recommendation {
    var lines: [String] { settings.map { "\($0.label): \($0.value)" } }

    /// Human-readable differences between what was run and this recommendation.
    func differences(from ran: RanSetup) -> [String] {
        var out: [String] = []
        if let v = ran.springValue, v != springValue {
            out.append("\(headlineLabel): \(v) \(headlineUnit) (recommended \(springValue))")
        }
        if let t = ran.tokens, let rec = tokens, t != rec {
            out.append("Volume spacers: \(t) (recommended \(rec))")
        }
        for c in clicks {
            if let v = ran.clicks[c.key], v != c.value {
                out.append("\(c.label): \(v) clicks \(c.direction) (recommended \(c.value))")
            }
        }
        return out
    }
}
