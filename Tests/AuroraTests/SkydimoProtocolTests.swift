import Testing
import AuroraCore
import AuroraDevice

@Suite("SkydimoProtocol")
struct SkydimoProtocolTests {
    @Test("single-red frame is byte-exact")
    func singleRedFrame() {
        let redFrame = [UInt8](SkydimoProtocol.frame([RGB(r: 255, g: 0, b: 0)], order: .rgb))
        #expect(redFrame == [0x41, 0x64, 0x61, 0x00, 0x00, 0x01, 0xFF, 0x00, 0x00])
    }

    @Test("GRB order swaps R and G")
    func grbOrderSwapsRAndG() {
        let grbTail = [UInt8](SkydimoProtocol.frame([RGB(r: 255, g: 10, b: 0)], order: .grb).suffix(3))
        #expect(grbTail == [10, 255, 0])
    }

    @Test("big-endian count for 300 LEDs (0x012C)")
    func bigEndianLEDCount() {
        let bigHeader = [UInt8](SkydimoProtocol.frame(Array(repeating: RGB.black, count: 300)).prefix(6))
        #expect(bigHeader == [0x41, 0x64, 0x61, 0x00, 0x01, 0x2C])
    }

    @Test("handshake reply validation")
    func handshakeReplyValidation() {
        #expect(SkydimoProtocol.isValidReply("  sk0124\r\n"), "handshake reply 'sk0124' is valid")
        #expect(!SkydimoProtocol.isValidReply("garbage"), "junk reply rejected")
    }

    @Test("controller catalog resolves known replies and rejects junk")
    func controllerCatalog() {
        #expect(ControllerCatalog.info(forReply: "SK0127,<config>")?.ledCount == 65, "catalog resolves SK0127 -> 65 LEDs")
        #expect(ControllerCatalog.info(forReply: "garbage") == nil, "catalog rejects junk reply")
    }
}

@Suite("Installation method")
struct InstallationMethodTests {
    @Test("fromLines builds correct LED count and extents")
    func fromLines() {
        let base = LEDLayout.fromLines([14, 26, 14])  // SK0124-like: W=26, H=14
        #expect(base.count == 54, "fromLines builds 54 LEDs for [14,26,14]")
        #expect(base.screenWidth == 26 && base.screenHeight == 14, "extents derived from per-side counts")
        let firstBase = base.points.first!
        #expect(firstBase.x == 0 && firstBase.y == 13, "LED 1 starts bottom-left in canonical layout")
    }

    @Test("LTR+bottomToTop is identity")
    func identityMethod() {
        let base = LEDLayout.fromLines([14, 26, 14])
        let identity = base.applying(InstallationMethod(horizontal: .leftToRight, vertical: .bottomToTop))
        #expect(identity.points.map { [$0.x, $0.y] } == base.points.map { [$0.x, $0.y] })
    }

    @Test("RTL+topToBottom flips LED 1 to top-right and matches the confirmed default")
    func flippedMethod() {
        let base = LEDLayout.fromLines([14, 26, 14])
        let firstBase = base.points.first!
        let userMethod = InstallationMethod(horizontal: .rightToLeft, vertical: .topToBottom)
        let flipped = base.applying(userMethod)
        let firstFlipped = flipped.points.first!
        #expect(firstFlipped.id == firstBase.id, "id/index order preserved under flip")
        #expect(firstFlipped.x == 25 && firstFlipped.y == 0, "RTL+topToBottom moves LED 1 to top-right (25,0)")
        #expect(InstallationMethod.default == userMethod, "default == user's confirmed setting (RTL + topToBottom)")

        let involutive = flipped.applying(userMethod)
        #expect(involutive.points.map { [$0.x, $0.y] } == base.points.map { [$0.x, $0.y] },
                "double-applying a method is involutive")
    }
}
