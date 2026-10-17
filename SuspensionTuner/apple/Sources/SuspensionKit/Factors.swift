import Foundation

// Extra things that change a setup beyond weight, height and frame size.
// Every field has a default that leaves the base recommendation unchanged, and decoding
// fills missing keys with those defaults so garages saved by older versions still load.

public enum PackLoad: String, Codable, CaseIterable, Identifiable {
    case none, hip, day, big
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .none: return "No pack"
        case .hip: return "Hip pack"
        case .day: return "Day pack"
        case .big: return "Big pack"
        }
    }
    /// Typical extra weight carried, lb
    public var lb: Double {
        switch self {
        case .none: return 0
        case .hip: return 5
        case .day: return 12
        case .big: return 20
        }
    }
}

public enum SagFeel: String, Codable, CaseIterable, Identifiable {
    case firm, balanced, plush
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum Terrain: String, Codable, CaseIterable, Identifiable {
    case mixed, rough, flow
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .mixed: return "Mixed"
        case .rough: return "Rocky / rooty"
        case .flow: return "Flow / jumps"
        }
    }
}

public enum TrailCondition: String, Codable, CaseIterable, Identifiable {
    case dry, wet
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum ClimbPriority: String, Codable, CaseIterable, Identifiable {
    case climb, balanced, descend
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .climb: return "Climbing"
        case .balanced: return "Balanced"
        case .descend: return "Descending"
        }
    }
}

public enum Skill: String, Codable, CaseIterable, Identifiable {
    case relaxed, intermediate, aggressive
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum RidingPosition: String, Codable, CaseIterable, Identifiable {
    case neutral, forward
    public var id: String { rawValue }
    public var title: String { self == .neutral ? "Centred" : "Over the front" }
}

public enum WheelSize: String, Codable, CaseIterable, Identifiable {
    case w29 = "29", w275 = "27.5", mixed
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .w29: return "29″"
        case .w275: return "27.5″"
        case .mixed: return "Mixed"
        }
    }
}

public enum TireWidth: String, Codable, CaseIterable, Identifiable {
    case standard, wide
    public var id: String { rawValue }
    public var title: String { self == .standard ? "2.3–2.4″" : "2.5–2.6″" }
}

/// How the frame's leverage ratio changes through the travel (from reviews or the frame maker's chart).
public enum FrameProgression: String, Codable, CaseIterable, Identifiable {
    case linear, average, progressive
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

/// Today's ride — changes often, set on the Garage screen.
public struct RideConditions: Codable, Hashable {
    public var terrain: Terrain
    public var condition: TrailCondition
    /// Riding temperature, °F
    public var temperatureF: Double
    public var pack: PackLoad
    public var feel: SagFeel
    public var priority: ClimbPriority

    public init(terrain: Terrain = .mixed, condition: TrailCondition = .dry, temperatureF: Double = 70,
                pack: PackLoad = .none, feel: SagFeel = .balanced, priority: ClimbPriority = .balanced) {
        self.terrain = terrain; self.condition = condition; self.temperatureF = temperatureF
        self.pack = pack; self.feel = feel; self.priority = priority
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = RideConditions()
        terrain = try c.decodeIfPresent(Terrain.self, forKey: .terrain) ?? d.terrain
        condition = try c.decodeIfPresent(TrailCondition.self, forKey: .condition) ?? d.condition
        temperatureF = try c.decodeIfPresent(Double.self, forKey: .temperatureF) ?? d.temperatureF
        pack = try c.decodeIfPresent(PackLoad.self, forKey: .pack) ?? d.pack
        feel = try c.decodeIfPresent(SagFeel.self, forKey: .feel) ?? d.feel
        priority = try c.decodeIfPresent(ClimbPriority.self, forKey: .priority) ?? d.priority
    }
}

/// Things about the bike itself — set in the bike editor.
public struct BikeSetup: Codable, Hashable {
    public var eBike: Bool
    public var wheel: WheelSize
    public var tireWidth: TireWidth
    public var inserts: Bool
    /// The frame maker's recommended rear sag, % (nil = use the shock maker's)
    public var frameRearSag: Double?
    public var frameProgression: FrameProgression
    /// Hours ridden since the last service
    public var forkHours: Double
    public var shockHours: Double

    public init(eBike: Bool = false, wheel: WheelSize = .w29, tireWidth: TireWidth = .standard, inserts: Bool = false,
                frameRearSag: Double? = nil, frameProgression: FrameProgression = .average,
                forkHours: Double = 0, shockHours: Double = 0) {
        self.eBike = eBike; self.wheel = wheel; self.tireWidth = tireWidth; self.inserts = inserts
        self.frameRearSag = frameRearSag; self.frameProgression = frameProgression
        self.forkHours = forkHours; self.shockHours = shockHours
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = BikeSetup()
        eBike = try c.decodeIfPresent(Bool.self, forKey: .eBike) ?? d.eBike
        wheel = try c.decodeIfPresent(WheelSize.self, forKey: .wheel) ?? d.wheel
        tireWidth = try c.decodeIfPresent(TireWidth.self, forKey: .tireWidth) ?? d.tireWidth
        inserts = try c.decodeIfPresent(Bool.self, forKey: .inserts) ?? d.inserts
        frameRearSag = try c.decodeIfPresent(Double.self, forKey: .frameRearSag)
        frameProgression = try c.decodeIfPresent(FrameProgression.self, forKey: .frameProgression) ?? d.frameProgression
        forkHours = try c.decodeIfPresent(Double.self, forKey: .forkHours) ?? d.forkHours
        shockHours = try c.decodeIfPresent(Double.self, forKey: .shockHours) ?? d.shockHours
    }
}
