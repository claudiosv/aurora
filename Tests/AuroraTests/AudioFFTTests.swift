import Testing
import Foundation
import AuroraAudio

@Suite("Audio FFT")
struct AudioFFTTests {
    @Test("FFT peak lands at the expected bin for a pure tone")
    func fftPeakAtExpectedBin() {
        let analyzer = SpectrumAnalyzer(size: 1024)
        let targetBin = 64
        let sr = 48_000.0
        let freq = sr * Double(targetBin) / 1024.0
        var sine = [Float](repeating: 0, count: 1024)
        for i in 0..<1024 { sine[i] = Float(sin(2 * Double.pi * freq * Double(i) / sr)) }
        let mags = analyzer.magnitudes(sine)

        var peakBin = 0
        var peakVal: Float = 0
        for (i, m) in mags.enumerated() where m > peakVal { peakVal = m; peakBin = i }

        #expect(abs(peakBin - targetBin) <= 2, "FFT peak at expected bin for a \(Int(freq))Hz tone (got bin \(peakBin))")
        #expect(peakVal > 0, "FFT produces non-zero magnitude for a tone")
    }

    @Test("FFT of silence is ~zero")
    func fftOfSilenceIsZero() {
        let analyzer = SpectrumAnalyzer(size: 1024)
        let silence = [Float](repeating: 0, count: 1024)
        #expect((analyzer.magnitudes(silence).max() ?? 1) < 0.001)
    }

    @Test("band grouping yields 24 non-empty bands")
    func bandGrouping() {
        let analyzer = SpectrumAnalyzer(size: 1024)
        let targetBin = 64
        let sr = 48_000.0
        let freq = sr * Double(targetBin) / 1024.0
        var sine = [Float](repeating: 0, count: 1024)
        for i in 0..<1024 { sine[i] = Float(sin(2 * Double.pi * freq * Double(i) / sr)) }
        let mags = analyzer.magnitudes(sine)
        let bands = analyzer.bands(mags, count: 24)
        #expect(bands.count == 24 && bands.contains { $0 > 0 })
    }
}
