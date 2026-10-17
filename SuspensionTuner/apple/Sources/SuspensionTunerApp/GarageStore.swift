import Foundation
import Observation
import SuspensionKit

enum AppTab: Hashable {
    case garage, tune, history, settings
}

/// Saved bikes + history, stored as JSON in Application Support. Also holds which tab / end is showing.
@Observable
final class GarageStore {
    let catalog = Catalog.bundled
    private(set) var data: GarageData
    private let fileURL: URL

    // Navigation (not saved)
    var tab: AppTab = .garage
    var tuneEnd: ComponentKind = .fork

    init(fileURL: URL = GarageStore.defaultURL) {
        self.fileURL = fileURL
        if let raw = try? Data(contentsOf: fileURL), let decoded = try? GarageData.decode(raw) {
            data = decoded
        } else {
            data = GarageData()
        }
    }

    static var defaultURL: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("SuspensionTuner", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("garage.json")
    }

    private func save() {
        do {
            try data.encoded().write(to: fileURL, options: .atomic)
        } catch {
            print("Suspension Tuner: could not save garage — \(error)")
        }
    }

    // MARK: Reading

    var bikes: [Bike] { data.bikes }
    var selectedBike: Bike? { data.selectedBike }
    var history: [HistoryEntry] { data.history }

    var useKilograms: Bool {
        get { data.useKilograms }
        set { data.useKilograms = newValue; save() }
    }

    /// Which of the three bike drawings this bike uses (by its place in the garage; the 4th reuses the 1st).
    func variant(for bike: Bike) -> Int {
        (data.bikes.firstIndex { $0.id == bike.id } ?? 0) % 3
    }

    func model(_ bike: Bike, _ end: ComponentKind) -> SuspensionModel? { catalog.model(for: bike, end: end) }
    func recommendation(_ bike: Bike, _ end: ComponentKind) -> Recommendation? { catalog.recommendation(for: bike, end: end) }

    func weightText(lb: Double) -> String {
        useKilograms ? "\(Int((lb / 2.20462).rounded())) kg" : "\(Int(lb.rounded())) lb"
    }

    // MARK: Changing

    func select(_ bike: Bike) {
        data.selectedBikeID = bike.id
        save()
    }

    /// Add a new bike or replace an existing one (matched by id) and make it the selected bike.
    func upsert(_ bike: Bike) {
        if let i = data.bikes.firstIndex(where: { $0.id == bike.id }) {
            data.bikes[i] = bike
        } else {
            data.bikes.append(bike)
        }
        data.selectedBikeID = bike.id
        save()
    }

    func delete(_ bike: Bike) {
        data.bikes.removeAll { $0.id == bike.id }
        if data.selectedBikeID == bike.id { data.selectedBikeID = data.bikes.first?.id }
        save()
    }

    func setStyle(_ style: RidingStyle, for bikeID: UUID) {
        update(bikeID) { $0.style = style }
    }

    func setRide(_ ride: RideConditions, for bikeID: UUID) {
        update(bikeID) { $0.ride = ride }
    }

    func setRan(_ ran: RanSetup, end: ComponentKind, for bikeID: UUID) {
        update(bikeID) { $0.setRan(ran, for: end) }
    }

    private func update(_ id: UUID, _ change: (inout Bike) -> Void) {
        guard let i = data.bikes.firstIndex(where: { $0.id == id }) else { return }
        change(&data.bikes[i])
        save()
    }

    func addHistory(_ entry: HistoryEntry) {
        data.history.insert(entry, at: 0)
        save()
    }

    func deleteHistory(_ entry: HistoryEntry) {
        data.history.removeAll { $0.id == entry.id }
        save()
    }

    func eraseAll() {
        data = GarageData(useKilograms: data.useKilograms)
        tab = .garage
        save()
    }
}

extension Bike {
    /// Blank bike for the "Add bike" sheet.
    static func blank() -> Bike {
        Bike(name: "", rider: RiderProfile(weightLb: 0, heightIn: 0, frameSize: .M))
    }
}
