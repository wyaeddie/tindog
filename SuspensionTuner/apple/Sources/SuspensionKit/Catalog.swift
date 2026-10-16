import Foundation

public enum ComponentKind: String, Codable, CaseIterable, Identifiable {
    case fork, shock
    public var id: String { rawValue }
    public var title: String { self == .fork ? "Fork · Front" : "Shock · Rear" }
}

public enum SpringType: String, Codable { case air, coil }

public enum RidingStyle: String, Codable, CaseIterable, Identifiable {
    case trail, enduro, park
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .trail: return "Trail"
        case .enduro: return "Enduro"
        case .park: return "Bike Park"
        }
    }
}

public enum FrameSize: String, Codable, CaseIterable, Identifiable {
    case S, M, L, XL
    public var id: String { rawValue }
    var index: Int { Self.allCases.firstIndex(of: self)! }
}

public struct Range3: Codable, Hashable {
    public let min: Double
    public let max: Double
    public let `default`: Double
}

public struct Tokens: Codable, Hashable {
    public let `default`: Int
    public let max: Int
}

public struct Adjusters: Codable, Hashable {
    public let rebound: Int
    public let lsc: Int
    public let hsc: Int
    public let lsr: Int
    public let hsr: Int
}

/// Where a recommendation's numbers come from.
public enum DataQuality: String, Codable {
    /// Taken from the maker's published setup chart
    case manufacturer
    /// Some values from the maker (pressure or sag), the rest estimated
    case partial
    /// No published chart found — calculated
    case estimate

    public var title: String {
        switch self {
        case .manufacturer: return "Manufacturer chart"
        case .partial: return "Partly manufacturer"
        case .estimate: return "Estimate"
        }
    }
}

/// A maker's chart: "steps" rows are [from, value] (e.g. the 180–190 lb row starts at 180);
/// "linear" rows are [x, y] points, interpolated between.
public struct ChartTable: Codable, Hashable {
    public let type: String
    public let rows: [[Double]]
    /// [min, max] travel this table applies to (nil = all)
    public let travel: [Double]?
}

public struct TokenRow: Codable, Hashable {
    public let travel: Double
    public let installed: Int
    public let max: Int
}

/// Maker's starting point for one adjuster.
public struct DampingRule: Codable, Hashable {
    /// rebound, lsr, hsr, lsc, hsc
    public let key: String
    /// weight (rider lb), psi, rate (lb/in), fixed, middle
    public let by: String
    /// closed = clicks out from fully closed; open = clicks in from fully open
    public let from: String
    /// [from, clicks] or [from, low, high] steps
    public let rows: [[Double]]?
}

public struct ManufacturerData: Codable, Hashable {
    public let quality: DataQuality
    public let source: String?
    public let sourceTitle: String
    /// Recommended sag range in % [min, max]
    public let sag: [Double]?
    public let pressure: [ChartTable]?
    /// "bodyWeight": start psi = rider weight in lb, then set sag
    public let pressureRule: String?
    /// Öhlins ramp-up chamber
    public let ramp: [ChartTable]?
    public let tokens: [TokenRow]?
    public let damping: [DampingRule]?
    /// FOX "E-Bike+" / Marzocchi e-bike charts
    public let ebikePressure: [ChartTable]?
    public let ebikeTokens: [TokenRow]?
    public let ebikeMaxPsi: Int?
}

public struct SuspensionModel: Codable, Hashable, Identifiable {
    public let id: String
    public let brand: String
    public let name: String
    public let kind: ComponentKind
    public let spring: SpringType
    public let category: String
    public let travel: Range3
    public let stroke: Range3?
    public let damper: String
    public let psiRatio: Double?
    public let maxPsi: Int?
    public let tokens: Tokens?
    public let adjusters: Adjusters
    public let climb: String?
    public let note: String
    public let url: String?
    public let mfg: ManufacturerData?

    public var quality: DataQuality { mfg?.quality ?? .estimate }
}

public struct Catalog: Codable {
    public let version: Int
    public let disclaimer: String
    public let models: [SuspensionModel]
    public let brandSites: [String: String]

    /// The bundled catalog (same JSON the Python app reads).
    public static let bundled: Catalog = {
        let url = Bundle.module.url(forResource: "catalog", withExtension: "json")!
        return try! JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    }()

    public func brands(for kind: ComponentKind) -> [String] {
        var seen = Set<String>()
        return models.filter { $0.kind == kind }.map(\.brand).filter { seen.insert($0).inserted }
    }

    /// Official product page when we have a verified one, else a search of the brand's own site.
    public func specsURL(for model: SuspensionModel) -> URL? {
        if let url = model.url { return URL(string: url) }
        guard let domain = brandSites[model.brand] else { return nil }
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: "site:\(domain) \(model.name) specs")]
        return components.url
    }

    public func models(for kind: ComponentKind, brand: String) -> [SuspensionModel] {
        models.filter { $0.kind == kind && $0.brand == brand }
    }
}
