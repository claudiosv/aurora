import Testing
import Foundation
import AuroraCore
import AuroraCircadian

@Suite("Persistence")
struct PersistenceTests {
    @Test("CircadianSettings survives a JSON round-trip")
    func circadianSettingsRoundTrip() throws {
        let saved = CircadianSettings(latitude: 1.5, longitude: 2.5, override: .night)
        let data = try JSONEncoder().encode(saved)
        let roundTrip = try JSONDecoder().decode(CircadianSettings.self, from: data)
        #expect(roundTrip == saved)
    }

    @Test("Mode is Codable")
    func modeIsCodable() throws {
        let data = try JSONEncoder().encode(Mode.circadian)
        let decoded = try? JSONDecoder().decode(Mode.self, from: data)
        #expect(decoded == .circadian)
    }
}
