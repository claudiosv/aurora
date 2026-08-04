import SwiftUI
import AuroraCore

/// Main window: live preview, mode switcher, mode-specific settings (circadian
/// today), and device status.
struct HomeView: View {
    @Bindable var model: AuroraModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                LEDStripView(frame: model.engine.lastFrame)
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

                Picker("Mode", selection: $model.mode) {
                    ForEach(Mode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch model.mode {
                case .circadian:
                    CircadianSettingsView(model: model)
                case .screenSync:
                    ScreenSyncSettingsView(model: model, screenSync: model.screenSync)
                case .musicSync:
                    MusicSyncSettingsView(model: model, musicSync: model.musicSync)
                case .staticColor:
                    StaticSettingsView(model: model)
                }

                GroupBox("Master brightness") {
                    HStack {
                        Image(systemName: "sun.min")
                        Slider(value: $model.brightness, in: 0...1)
                        Image(systemName: "sun.max")
                    }
                    .foregroundStyle(.secondary)
                    .padding(6)
                }

                GroupBox("Installation method") {
                    LayoutSetupView(model: model).padding(6)
                }

                Toggle("Launch Aurora at login", isOn: $model.launchAtLogin)
                    .font(.callout)

                HStack(spacing: 8) {
                    Label(model.deviceStatus,
                          systemImage: model.hasRealDevice ? "cable.connector" : "eye")
                        .font(.caption)
                        .foregroundStyle(model.hasRealDevice ? Color.green : .secondary)
                    Spacer()
                    Button {
                        model.rescan()
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                    .help("Detect a controller you just plugged in, or switch to a different strip")
                }
            }
            .padding(24)
        }
        .frame(minWidth: 480, minHeight: 560)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.max.fill").font(.title).foregroundStyle(.yellow)
            Text("Aurora").font(.largeTitle.bold())
            Spacer()
        }
    }
}

/// Placeholder shown for modes that aren't wired up yet.
struct ContentUnavailablePlaceholder: View {
    let mode: Mode

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: mode.symbol).font(.largeTitle).foregroundStyle(.secondary)
            Text("\(mode.title) is coming soon").font(.headline)
            Text("Circadian mode is fully available today.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
