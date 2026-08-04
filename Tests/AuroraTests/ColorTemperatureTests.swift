import Testing
import Foundation
import AuroraCore

@Suite("ColorTemperature")
struct ColorTemperatureTests {
    @Test("warm is redder than blue")
    func warmIsRedderThanBlue() {
        let warm = ColorTemperature.rgb(kelvin: 1900)
        #expect(warm.r > warm.b)
    }

    @Test("cool is not red-dominant")
    func coolIsNotRedDominant() {
        let cool = ColorTemperature.rgb(kelvin: 6500)
        #expect(Int(cool.b) + 20 >= Int(cool.r))
    }

    @Test("clamps out-of-range without crashing")
    func clampsOutOfRange() {
        _ = ColorTemperature.rgb(kelvin: -100)
        _ = ColorTemperature.rgb(kelvin: 100_000)
    }

    @Test("capping never brightens, and is a no-op at/above 6500K")
    func capping() {
        let coolWhite = RGB(r: 255, g: 255, b: 255)
        let cappedWhite = ColorTemperature.capped(coolWhite, maxKelvin: 3000)
        #expect(cappedWhite.b < coolWhite.b, "capped white is less blue than uncapped")
        #expect(cappedWhite.r == coolWhite.r, "capped white keeps full red (reference is always 255)")
        #expect(ColorTemperature.capped(coolWhite, maxKelvin: 6500) == coolWhite, "6500K+ cap is a no-op")

        let warmSource = RGB(r: 255, g: 120, b: 40)
        let cappedWarm = ColorTemperature.capped(warmSource, maxKelvin: 3000)
        #expect(cappedWarm.r <= warmSource.r && cappedWarm.g <= warmSource.g && cappedWarm.b <= warmSource.b,
                "capping never brightens a channel")
    }
}

@Suite("RGB")
struct RGBTests {
    @Test("scaled-by-0 is black")
    func scaledByZeroIsBlack() {
        #expect(RGB.white.scaled(by: 0) == .black)
    }

    @Test("blend midpoint")
    func blendMidpoint() {
        #expect(RGB.black.blended(to: .white, t: 0.5) == RGB(r: 128, g: 128, b: 128))
    }

    @Test("RGB survives a JSON round-trip (static color persistence)")
    func jsonRoundTrip() throws {
        let data = try JSONEncoder().encode(RGB(r: 12, g: 34, b: 56))
        let roundTrip = try JSONDecoder().decode(RGB.self, from: data)
        #expect(roundTrip == RGB(r: 12, g: 34, b: 56))
    }
}

@Suite("RGB HSV")
struct RGBHSVTests {
    @Test("hue 0 = red")
    func hueZeroIsRed() {
        #expect(RGB.hsv(0, 1, 1) == RGB(r: 255, g: 0, b: 0))
    }

    @Test("hue 1/3 = green")
    func hueOneThirdIsGreen() {
        let green = RGB.hsv(1.0 / 3.0, 1, 1)
        #expect(green.g > green.r && green.g > green.b)
    }
}

@Suite("Gamma (LED color correction)")
struct GammaTests {
    @Test("gamma preserves white and black")
    func gammaPreservesExtremes() {
        #expect(RGB.white.gammaCorrected(2.8) == .white)
        #expect(RGB.black.gammaCorrected(2.8) == .black)
    }

    @Test("gamma shifts a warm color toward orange")
    func gammaShiftsWarmTowardOrange() {
        let warm = ColorTemperature.rgb(kelvin: 1600)
        let warmG = warm.gammaCorrected(2.8)
        #expect(warmG.g < warm.g, "gamma lowers the green channel of a warm color")

        let ratioBefore = Double(warm.g) / Double(max(warm.r, 1))
        let ratioAfter = Double(warmG.g) / Double(max(warmG.r, 1))
        #expect(ratioAfter < ratioBefore, "gamma shifts warm color toward orange (lower green:red ratio)")
    }
}
