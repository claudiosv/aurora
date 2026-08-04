import Foundation
import Combine
import AuroraCore
import AuroraDevice
import AuroraCircadian
import AuroraEngine
import AuroraCapture
import AuroraAudio

/// Carries the detection result from the render-queue swap back to the main
/// thread (written in `build`, read in `completion` — ordered, so safe).
private final class RescanBox: @unchecked Sendable {
    var detected: DetectedController?
}

/// App-level view model (the single source of truth the UI binds to). Wraps the
/// engine + modes, supports swapping the controller at runtime (Rescan / hot-plug),
/// and remembers installation direction + brightness **per controller model**.
@MainActor
final class AuroraModel: ObservableObject {
    let engine: LightEngine
    let circadian: CircadianMode
    let screenSync: ScreenSyncController
    let musicSync: MusicSyncController
    let locationProvider = LocationProvider()

    /// Live device identity (updates on Rescan).
    @Published private(set) var detectedInfo: ControllerInfo?
    @Published private(set) var portPath: String?
    @Published private(set) var ledCount: Int

    let outputGamma: Double = 2.8
    private let simLedCount = 54

    private var baseLayout: LEDLayout
    private var deviceSettings: [String: DeviceSettings]
    private var currentDeviceKey: String

    @Published var mode: Mode {
        didSet {
            engine.setMode(mode)
            updateCaptureState()
            if previewHour != nil { previewHour = nil }
            persist()
        }
    }
    @Published var brightness: Double {
        didSet { engine.setBrightness(brightness); saveDevice(); persist() }
    }
    @Published var circadianSettings: CircadianSettings {
        didSet {
            circadian.settings = circadianSettings
            engine.setProvider(makeCircadianProvider(), for: .circadian)
            persist()
        }
    }
    /// Remembered per controller model.
    @Published var installationMethod: InstallationMethod {
        didSet {
            screenSync.updateLayout(previewLayout)
            musicSync.updateLayout(previewLayout)
            saveDevice()
            persist()
        }
    }
    @Published var screenSyncSubMode: ScreenSyncSubMode {
        didSet { screenSync.subMode = screenSyncSubMode; persist() }
    }
    @Published var screenSyncSaturation: Double {
        didSet { screenSync.saturation = screenSyncSaturation; persist() }
    }
    /// Max color temperature Screen Sync colors are allowed to read as; nil = uncapped.
    @Published var screenSyncMaxKelvin: Double? {
        didSet { screenSync.maxKelvin = screenSyncMaxKelvin; persist() }
    }
    @Published var screenSyncCaptureFPS: Double {
        didSet { screenSync.captureFPS = screenSyncCaptureFPS; persist() }
    }
    @Published var musicMode: MusicMode {
        didSet { musicSync.mode = musicMode; persist() }
    }
    @Published var musicSensitivity: Double {
        didSet { musicSync.sensitivity = musicSensitivity; persist() }
    }
    @Published var staticColor: RGB {
        didSet { engine.setProvider(staticProvider(), for: .staticColor); persist() }
    }
    @Published var launchAtLogin: Bool {
        didSet { LoginItem.setEnabled(launchAtLogin) }
    }
    @Published var previewHour: Double? {
        didSet { engine.setPreviewTime(previewHour.map(dateFor(hour:))) }
    }

    @Published private(set) var lastFrame: [RGB] = []
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isConnected: Bool = false

    init() {
        let saved = Persistence.load()
        let detected = DeviceManager.detect()

        let info = detected?.info
        let key = info?.model ?? "simulator"
        let lines = info?.lines ?? [14, 26, 14]

        let devSettings = saved?.deviceSettings ?? [:]
        let ds = devSettings[key]
        let method = ds?.installationMethod ?? saved?.installationMethod ?? .default
        let startBrightness = ds?.brightness ?? saved?.brightness ?? 1.0

        let controller: LEDController = detected.map { DeviceManager.makeController(for: $0) }
            ?? SimulatedLEDController(layout: .strip(count: simLedCount))

        let base = LEDLayout.fromLines(lines)
        let spatial = base.applying(method)

        let settings = saved?.circadian ?? CircadianSettings(latitude: 55.75, longitude: 37.62)
        self.circadian = CircadianMode(settings: settings)

        let subMode = saved?.screenSyncSubMode ?? .full
        let saturation = saved?.screenSyncSaturation ?? 1.15
        let maxKelvin = saved?.screenSyncMaxKelvin
        let captureFPS = saved?.screenSyncCaptureFPS ?? 30
        let ss = ScreenSyncController(spatialLayout: spatial, subMode: subMode, saturation: saturation, maxKelvin: maxKelvin, captureFPS: captureFPS)
        self.screenSync = ss

        let musicModeStart = saved?.musicMode ?? .spectrum
        let musicSens = saved?.musicSensitivity ?? 1.0
        let ms = MusicSyncController(spatialLayout: spatial, mode: musicModeStart, sensitivity: musicSens)
        self.musicSync = ms

        let startMode = saved?.mode ?? .circadian
        let staticColorStart = saved?.staticColor ?? ColorTemperature.rgb(kelvin: 2700)
        let gamma = 2.8

        let circadianProvider = AuroraModel.circadianProvider(settings: settings, gamma: gamma)
        let screenProvider: @Sendable (Date, LEDLayout) -> [RGB] = { _, _ in ss.currentFrame() }
        let musicProvider: @Sendable (Date, LEDLayout) -> [RGB] = { _, _ in ms.currentFrame() }
        let staticGamma = staticColorStart.gammaCorrected(gamma)
        let staticProviderFn: @Sendable (Date, LEDLayout) -> [RGB] = { _, layout in
            Array(repeating: staticGamma, count: layout.count)
        }
        let eng = LightEngine(
            controller: controller,
            providers: [
                .circadian: circadianProvider,
                .screenSync: screenProvider,
                .musicSync: musicProvider,
                .staticColor: staticProviderFn,
            ],
            mode: startMode,
            brightness: startBrightness,
            fps: 30
        )
        self.engine = eng

        self.detectedInfo = info
        self.portPath = detected?.portPath
        self.ledCount = info?.ledCount ?? simLedCount
        self.baseLayout = base
        self.deviceSettings = devSettings
        self.currentDeviceKey = key

        self.mode = startMode
        self.brightness = startBrightness
        self.circadianSettings = settings
        self.installationMethod = method
        self.screenSyncSubMode = subMode
        self.screenSyncSaturation = saturation
        self.screenSyncMaxKelvin = maxKelvin
        self.screenSyncCaptureFPS = captureFPS
        self.musicMode = musicModeStart
        self.musicSensitivity = musicSens
        self.staticColor = staticColorStart
        self.launchAtLogin = LoginItem.isEnabled

        eng.$lastFrame.assign(to: &$lastFrame)
        eng.$isRunning.assign(to: &$isRunning)
        eng.$isConnected.assign(to: &$isConnected)

        locationProvider.onUpdate = { [weak self] lat, lon in
            guard let self else { return }
            self.circadianSettings.latitude = lat
            self.circadianSettings.longitude = lon
        }

        eng.start()
        updateCaptureState()
    }

    // MARK: Intents

    func togglePause() { engine.setPaused(isRunning) }
    func requestLocation() { locationProvider.request() }
    func startScreenCapture() { screenSync.start() }
    func startMusicCapture() { musicSync.start() }

    /// Re-detect the controller and swap to it live (Rescan / after a hot-plug),
    /// restoring that model's remembered settings. Detection runs with the port
    /// freed (inside the engine swap) so it can't fail on our own open handle.
    func rescan() {
        let box = RescanBox()
        let simCount = simLedCount
        engine.replaceController(
            build: {
                let detected = DeviceManager.detect()
                box.detected = detected
                if let detected { return DeviceManager.makeController(for: detected) }
                return SimulatedLEDController(layout: .strip(count: simCount))
            },
            completion: { [weak self] in
                MainActor.assumeIsolated { self?.applyRescan(box.detected) }
            }
        )
    }

    private func applyRescan(_ detected: DetectedController?) {
        let info = detected?.info
        let key = info?.model ?? "simulator"
        detectedInfo = info
        portPath = detected?.portPath
        ledCount = info?.ledCount ?? simLedCount
        baseLayout = LEDLayout.fromLines(info?.lines ?? [14, 26, 14])
        currentDeviceKey = key
        // Restore this model's remembered orientation + brightness (didSets
        // re-point the capture layouts, the engine brightness, and persist).
        let ds = deviceSettings[key]
        installationMethod = ds?.installationMethod ?? .default
        brightness = ds?.brightness ?? 1.0
        screenSync.updateLayout(previewLayout)
        musicSync.updateLayout(previewLayout)
    }

    var deviceStatus: String {
        if let info = detectedInfo {
            let port = portPath.map { ($0 as NSString).lastPathComponent } ?? "?"
            return "\(info.model) · \(info.ledCount) LEDs · \(port)"
        }
        return "Preview only · \(ledCount) LEDs"
    }

    var hasRealDevice: Bool { detectedInfo != nil }
    var previewLayout: LEDLayout { baseLayout.applying(installationMethod) }

    func todaySchedule() -> [SchedulePoint] { circadian.daySchedule(on: Date()) }

    var nowHour: Double {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60
    }

    func displayColor(kelvin: Double, brightness: Double = 1) -> RGB {
        ColorTemperature.rgb(kelvin: kelvin).gammaCorrected(outputGamma).scaled(by: brightness)
    }

    // MARK: Private

    private func updateCaptureState() {
        if mode == .screenSync { screenSync.start() } else { screenSync.stop() }
        if mode == .musicSync { musicSync.start() } else { musicSync.stop() }
    }

    private func saveDevice() {
        deviceSettings[currentDeviceKey] = DeviceSettings(installationMethod: installationMethod, brightness: brightness)
    }

    private func makeCircadianProvider() -> @Sendable (Date, LEDLayout) -> [RGB] {
        AuroraModel.circadianProvider(settings: circadianSettings, gamma: outputGamma)
    }

    private static func circadianProvider(
        settings: CircadianSettings,
        gamma: Double
    ) -> @Sendable (Date, LEDLayout) -> [RGB] {
        return { date, layout in
            let mode = CircadianMode(settings: settings)
            let color = ColorTemperature.rgb(kelvin: mode.currentKelvin(at: date))
                .gammaCorrected(gamma)
                .scaled(by: mode.brightness(at: date))
            return Array(repeating: color, count: layout.count)
        }
    }

    private func staticProvider() -> @Sendable (Date, LEDLayout) -> [RGB] {
        let color = staticColor.gammaCorrected(outputGamma)
        return { _, layout in Array(repeating: color, count: layout.count) }
    }

    private func dateFor(hour: Double) -> Date {
        let start = Calendar.current.startOfDay(for: Date())
        return start.addingTimeInterval(hour * 3600)
    }

    private func persist() {
        Persistence.save(SavedState(
            mode: mode,
            brightness: brightness,
            circadian: circadianSettings,
            installationMethod: installationMethod,
            screenSyncSubMode: screenSyncSubMode,
            screenSyncSaturation: screenSyncSaturation,
            screenSyncMaxKelvin: screenSyncMaxKelvin,
            screenSyncCaptureFPS: screenSyncCaptureFPS,
            musicMode: musicMode,
            musicSensitivity: musicSensitivity,
            staticColor: staticColor,
            deviceSettings: deviceSettings
        ))
    }
}
