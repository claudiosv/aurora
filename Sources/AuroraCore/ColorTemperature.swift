import Foundation

/// Converts a correlated color temperature (Kelvin) to an approximate sRGB color.
///
/// Uses Tanner Helland's widely-used approximation, valid ~1000K–40000K. Good
/// enough for ambient lighting and the circadian schedule.
public enum ColorTemperature {
    public static func rgb(kelvin: Double) -> RGB {
        let temp = max(1000, min(40000, kelvin)) / 100

        let r: Double
        if temp <= 66 {
            r = 255
        } else {
            r = 329.698727446 * pow(temp - 60, -0.1332047592)
        }

        let g: Double
        if temp <= 66 {
            g = 99.4708025861 * log(temp) - 161.1195681661
        } else {
            g = 288.1221695283 * pow(temp - 60, -0.0755148492)
        }

        let b: Double
        if temp >= 66 {
            b = 255
        } else if temp <= 19 {
            b = 0
        } else {
            b = 138.5177312231 * log(temp - 10) - 305.0447927307
        }

        func clamp(_ v: Double) -> UInt8 { UInt8(max(0, min(255, v))) }
        return RGB(r: clamp(r), g: clamp(g), b: clamp(b))
    }

    /// Caps how cool (blue-shifted) a color can read, by scaling it toward
    /// `maxKelvin`'s reference white point — the same technique warm-color
    /// filters (e.g. Night Shift) use. Used to keep Screen Sync from throwing
    /// harsh blue-white light when the source content (a bright IDE, a white
    /// webpage) is cooler than desired. A no-op at/above ~6500K, since that's
    /// already roughly neutral daylight white — nothing captured from a screen
    /// reads cooler than that in a way this should touch.
    public static func capped(_ color: RGB, maxKelvin: Double) -> RGB {
        guard maxKelvin < 6500 else { return color }
        let ref = rgb(kelvin: maxKelvin)
        func scale(_ v: UInt8, _ refV: UInt8) -> UInt8 {
            UInt8((Double(v) * Double(refV) / 255).rounded())
        }
        return RGB(r: scale(color.r, ref.r), g: scale(color.g, ref.g), b: scale(color.b, ref.b))
    }
}
