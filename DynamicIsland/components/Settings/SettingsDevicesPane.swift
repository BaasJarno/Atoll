//
//  SettingsDevicesPane.swift
//  DynamicIsland
//
//  Created by Richard Kunkli on 07/08/2024.
//  Split out of SettingsView.swift, which had grown past 9,600 lines.
//

import AppKit
import AVFoundation
import Combine
import Defaults
import EventKit
import KeyboardShortcuts
import LaunchAtLogin
import LottieUI
import Sparkle
import SwiftUI
import SwiftUIIntrospect
import UniformTypeIdentifiers

struct DevicesSettingsView: View {
    @Default(.progressBarStyle) var progressBarStyle
    @Default(.useBluetoothHUD3DIcon) private var useBluetoothHUD3DIcon
    @Default(.enablePerAppVolume) private var enablePerAppVolume

    private func highlightID(_ title: String) -> String {
        SettingsTab.devices.highlightID(for: title)
    }

    private var colorCodingDisabled: Bool {
        progressBarStyle == .segmented
    }

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enablePerAppVolume) {
                    Text("Enable per-app volume")
                }
                .settingsHighlight(id: highlightID("Enable per-app volume"))

                Defaults.Toggle(key: .showPerAppVolumeIcon) {
                    Text("Show app volume icon in the notch")
                }
                .disabled(!enablePerAppVolume)
                .settingsHighlight(id: highlightID("Show app volume icon in the notch"))

                Button("Reset all app volumes") {
                    PerAppVolumeManager.shared.resetAll()
                }
                .disabled(!enablePerAppVolume)
                .settingsHighlight(id: highlightID("Reset all app volumes"))
            } header: {
                Text("App Volume")
            } footer: {
                Text("Gives each app its own volume and mute, independent of the system volume. macOS will ask for audio recording permission the first time an app's level is changed: routing an app's audio through Atoll is the only way it can be adjusted, and nothing is ever recorded or written to disk. Apps left at 100% and unmuted keep their normal, untouched path to the speakers.")
            }

            Section {
                Defaults.Toggle(key: .showBluetoothDeviceConnections) {
                    Text("Show Bluetooth device connections")
                }
                .settingsHighlight(id: highlightID("Show Bluetooth device connections"))
                Defaults.Toggle(key: .useCircularBluetoothBatteryIndicator) {
                    Text("Use circular battery indicator")
                }
                .settingsHighlight(id: highlightID("Use circular battery indicator"))
                Defaults.Toggle(key: .showBluetoothBatteryPercentageText) {
                    Text("Show battery percentage text in HUD")
                }
                .settingsHighlight(id: highlightID("Show battery percentage text in HUD"))
                Defaults.Toggle(key: .showBluetoothDeviceNameMarquee) {
                    Text("Scroll device name in HUD")
                }
                .settingsHighlight(id: highlightID("Scroll device name in HUD"))
                Defaults.Toggle(key: .showAirPodsListeningModeChanges) {
                    Text("Show AirPods listening mode changes")
                }
                .settingsHighlight(id: highlightID("Show AirPods listening mode changes"))
                VStack(alignment: .leading, spacing: 12) {
                    Text("HUD icon style")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 16) {
                        Spacer(minLength: 0)
                        BluetoothHUDIconStyleCard(
                            style: .symbol,
                            isSelected: !useBluetoothHUD3DIcon
                        ) {
                            useBluetoothHUD3DIcon = false
                        }
                        BluetoothHUDIconStyleCard(
                            style: .threeD,
                            isSelected: useBluetoothHUD3DIcon
                        ) {
                            useBluetoothHUD3DIcon = true
                        }
                        Spacer(minLength: 0)
                    }
                }
                .settingsHighlight(id: highlightID("Use 3D Bluetooth HUD icon"))
            } header: {
                Text("Bluetooth Audio Devices")
            } footer: {
                Text("Displays a HUD notification when Bluetooth audio devices (headphones, AirPods, speakers) connect, showing device name and battery level.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                Defaults.Toggle(key: .useColorCodedBatteryDisplay) {
                    Text("Color-coded battery display")
                }
                .disabled(colorCodingDisabled)
                .settingsHighlight(id: highlightID("Color-coded battery display"))
            } header: {
                Text("Battery Indicator Styling")
            } footer: {
                if progressBarStyle == .segmented {
                    Text("Color-coded fills are unavailable in Segmented mode. Switch to Hierarchical or Gradient inside Controls › Dynamic Island to adjust advanced options.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else if Defaults[.useSmoothColorGradient] {
                    Text("Smooth transitions blend Green (0–60%), Yellow (60–85%), and Red (85–100%) through the entire fill. Adjust gradient behavior from Controls › Dynamic Island.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    Text("Discrete transitions snap between Green (0–60%), Yellow (60–85%), and Red (85–100%).")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Devices")
    }
}

private extension DevicesSettingsView {
    enum BluetoothHUDIconStyle: String {
        case symbol
        case threeD

        var title: String {
            switch self {
            case .symbol:
                return "Symbol"
            case .threeD:
                return "3D"
            }
        }
    }

    struct BluetoothHUDIconStyleCard: View {
        let style: BluetoothHUDIconStyle
        let isSelected: Bool
        let action: () -> Void

        @State private var isHovering = false

        var body: some View {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
                        )

                    preview
                }
                .frame(width: 90, height: 64)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovering = hovering
                    }
                }

                Text(style.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .contentShape(Rectangle())
            .onTapGesture { action() }
        }

        private var preview: some View {
            Group {
                switch style {
                case .symbol:
                    Image(systemName: BluetoothAudioDeviceType.airpods.sfSymbol)
                        .font(.system(size: 24, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                case .threeD:
                    if let url = BluetoothAudioDeviceType.airpods.inlineHUDAnimationURL {
                        SettingsLoopingVideoIcon(url: url, size: CGSize(width: 28, height: 28))
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: BluetoothAudioDeviceType.airpods.sfSymbol)
                            .font(.system(size: 24, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }

        private var backgroundColor: Color {
            if isSelected { return Color.accentColor.opacity(0.12) }
            if isHovering { return Color.primary.opacity(0.05) }
            return Color(nsColor: .controlBackgroundColor)
        }

        private var borderColor: Color {
            if isSelected { return Color.accentColor }
            if isHovering { return Color.primary.opacity(0.1) }
            return Color.clear
        }
    }
}

