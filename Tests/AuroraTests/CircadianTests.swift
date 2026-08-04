import Testing
import Foundation
import AuroraCore
import AuroraCircadian

func utc(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
}

@Suite("SolarPosition")
struct SolarPositionTests {
    @Test("sun higher at local noon than midnight, and above the horizon in summer")
    func solarElevation() {
        let noon = SolarPosition.elevationDegrees(date: utc(2026, 6, 21, 9), latitude: 55.75, longitude: 37.62)
        let midnight = SolarPosition.elevationDegrees(date: utc(2026, 6, 21, 21), latitude: 55.75, longitude: 37.62)
        #expect(noon > midnight, "sun higher at local noon than midnight")
        #expect(noon > 0, "summer local-noon sun is above the horizon")
    }
}

@Suite("Circadian")
struct CircadianTests {
    private func makeMode() -> CircadianMode {
        CircadianMode(settings: CircadianSettings(latitude: 55.75, longitude: 37.62))
    }

    @Test("daylight is cooler than night, and frame length matches layout")
    func circadianBasics() {
        let mode = makeMode()
        #expect(mode.currentKelvin(at: utc(2026, 6, 21, 9)) > mode.currentKelvin(at: utc(2026, 12, 21, 0)),
                "daylight cooler than night")
        #expect(mode.frame(at: Date(), layout: .strip(count: 54)).count == 54,
                "frame length matches layout count")
    }

    @Test("daySchedule returns the requested sample count, spanning 0..<24")
    func schedulePreview() {
        let schedule = makeMode().daySchedule(on: utc(2026, 6, 21, 12), samples: 96)
        #expect(schedule.count == 96, "daySchedule returns the requested sample count")
        #expect(schedule.first!.hour == 0 && schedule.last!.hour < 24, "schedule hours span 0..<24")
    }
}

@Suite("Circadian override")
struct CircadianOverrideTests {
    @Test("override=day forces day Kelvin and full brightness even at midnight")
    func dayOverride() {
        var settings = CircadianSettings(latitude: 55.75, longitude: 37.62)
        settings.override = .day
        let dayMode = CircadianMode(settings: settings)
        #expect(dayMode.currentKelvin(at: utc(2026, 1, 1, 0)) == settings.dayKelvin,
                "override=day forces day Kelvin even at midnight")
        #expect(dayMode.brightness(at: utc(2026, 1, 1, 0)) == 1, "override=day forces full brightness")
    }

    @Test("override=night forces night Kelvin even at noon")
    func nightOverride() {
        var settings = CircadianSettings(latitude: 55.75, longitude: 37.62)
        settings.override = .night
        let nightMode = CircadianMode(settings: settings)
        #expect(nightMode.currentKelvin(at: utc(2026, 6, 21, 12)) == settings.nightKelvin,
                "override=night forces night Kelvin even at noon")
    }
}
