import SwiftUI
import AppKit
import AuroraCore
import AuroraCapture

/// Screen Sync controls: sub-mode, saturation, capture status + permission prompt.
struct ScreenSyncSettingsView: View {
    @ObservedObject var model: AuroraModel
    @ObservedObject var screenSync: ScreenSyncController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusRow

            Picker("Region", selection: $model.screenSyncSubMode) {
                ForEach(ScreenSyncSubMode.allCases, id: \.self) { sub in
                    Label(sub.title, systemImage: sub.symbol).tag(sub)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            GroupBox("Saturation") {
                HStack {
                    Image(systemName: "drop")
                    Slider(value: $model.screenSyncSaturation, in: 0.5...2.0)
                    Image(systemName: "drop.fill")
                    Text(String(format: "%.0f%%", model.screenSyncSaturation * 100))
                        .frame(width: 48, alignment: .trailing).monospacedDigit()
                }
                .foregroundStyle(.secondary)
                .padding(6)
            }

            GroupBox("Capture Frame Rate") {
                HStack {
                    Image(systemName: "gauge.low")
                    Slider(value: $model.screenSyncCaptureFPS, in: 1...60, step: 1)
                    Image(systemName: "gauge.high")
                    Text("\(Int(model.screenSyncCaptureFPS)) fps")
                        .frame(width: 48, alignment: .trailing).monospacedDigit()
                }
                .foregroundStyle(.secondary)
                .padding(6)
            }

            GroupBox("Max Color Temperature") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Limit maximum temperature", isOn: maxKelvinEnabled)
                    if model.screenSyncMaxKelvin != nil {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(model.displayColor(kelvin: maxKelvinValue.wrappedValue).swiftUIColor)
                                .frame(width: 24, height: 16)
                                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.15)))
                            Slider(value: maxKelvinValue, in: 1200...6500, step: 100)
                            Text("\(Int(maxKelvinValue.wrappedValue))K")
                                .frame(width: 50, alignment: .trailing).monospacedDigit()
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(6)
            }

            Text("Mirrors the colors at the edges of your screen onto the strip. Pick a region to sync only part of the display. Limiting the max temperature keeps bright, cool screen content (white pages, IDEs) from throwing harsh blue-white light.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var maxKelvinEnabled: Binding<Bool> {
        Binding(
            get: { model.screenSyncMaxKelvin != nil },
            set: { model.screenSyncMaxKelvin = $0 ? (model.screenSyncMaxKelvin ?? 5000) : nil }
        )
    }

    private var maxKelvinValue: Binding<Double> {
        Binding(
            get: { model.screenSyncMaxKelvin ?? 5000 },
            set: { model.screenSyncMaxKelvin = $0 }
        )
    }

    @ViewBuilder
    private var statusRow: some View {
        switch screenSync.status {
        case .capturing:
            Label("Capturing your screen", systemImage: "record.circle")
                .font(.caption).foregroundStyle(.green)
        case .starting:
            Label("Starting…", systemImage: "hourglass")
                .font(.caption).foregroundStyle(.secondary)
        case .idle:
            Label("Idle", systemImage: "pause.circle")
                .font(.caption).foregroundStyle(.secondary)
        case .needsPermission:
            VStack(alignment: .leading, spacing: 6) {
                Label("Screen Recording permission needed", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
                Button("Open System Settings → Screen Recording") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Text("Grant Aurora access, then quit and reopen the app.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                Label("Capture failed", systemImage: "xmark.octagon")
                    .font(.caption).foregroundStyle(.red)
                Text(message).font(.caption2).foregroundStyle(.secondary)
                Button("Retry") { model.startScreenCapture() }
            }
        }
    }
}
