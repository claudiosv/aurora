import Testing
import AuroraCore
import AuroraCapture

@Suite("Screen sync sampler")
struct ScreenSyncSamplerTests {
    @Test("EdgeSampler produces one color per LED, sampling the correct screen edge")
    func edgeSampling() {
        var px = [RGB]()
        for _ in 0..<4 { for x in 0..<4 { px.append(x < 2 ? RGB(r: 255, g: 0, b: 0) : RGB(r: 0, g: 0, b: 255)) } }
        let grid = PixelGrid(width: 4, height: 4, pixels: px)
        let layout = LEDLayout.fromLines([2, 2, 2])   // 6 LEDs, W=2 H=2
        let sampled = EdgeSampler.sample(grid: grid, layout: layout, subMode: .full, saturation: 1.0)

        #expect(sampled.count == layout.count, "sampler returns one color per LED")
        #expect(sampled.first!.r > sampled.first!.b, "left LED (x=0) samples the red left side")
        #expect(sampled.last!.b > sampled.last!.r, "right LED (x=max) samples the blue right side")
    }

    @Test("leftHalf source rect covers the left screen half")
    func leftHalfSourceRect() {
        let half = ScreenSyncSubMode.leftHalf.sourceRect
        #expect(half.x1 == 0.5)
    }
}
