import Foundation
import AuroraCore
import AuroraCircadian
import AuroraCapture
import AuroraAudio

/// Settings that are remembered **per controller model** (a 32″ strip wound
/// left-to-right and a 27″ wound right-to-left keep their own orientation).
struct DeviceSettings: Codable, Equatable {
    var installationMethod: InstallationMethod
    var brightness: Double
}

/// The snapshot of user state we persist across launches.
struct SavedState: Codable {
    var mode: Mode
    var brightness: Double
    var circadian: CircadianSettings
    var installationMethod: InstallationMethod?       // legacy global (migration)
    var screenSyncSubMode: ScreenSyncSubMode?
    var screenSyncSaturation: Double?
    var musicMode: MusicMode?
    var musicSensitivity: Double?
    var staticColor: RGB?
    var deviceSettings: [String: DeviceSettings]?     // NEW: keyed by controller model
}

/// Tiny UserDefaults-backed store for `SavedState`.
enum Persistence {
    private static let key = "aurora.state.v1"

    static func load() -> SavedState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SavedState.self, from: data)
    }

    static func save(_ state: SavedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
