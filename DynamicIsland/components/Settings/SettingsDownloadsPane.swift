//
//  SettingsDownloadsPane.swift
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

struct Downloads: View {
    @Default(.selectedDownloadIndicatorStyle) var selectedDownloadIndicatorStyle
    @Default(.selectedDownloadIconStyle) var selectedDownloadIconStyle
    @Default(.enableDownloadListener) var enableDownloadListener

    private func highlightID(_ title: String) -> String {
        SettingsTab.downloads.highlightID(for: title)
    }

    var body: some View {
        SwiftUI.Form {
            Section {
                Defaults.Toggle(key: .enableDownloadListener) {
                    Text("Enable download detection")
                }
                .settingsHighlight(id: highlightID("Enable download detection"))
                VStack(alignment: .leading, spacing: 12) {
                    Text("Download indicator style")
                        .font(.system(size: 13, weight: .semibold))
                        // .white is invisible against a light Settings window;
                        // the label follows the appearance like every other one.
                        .foregroundStyle(enableDownloadListener ? Color.primary : Color.secondary)

                    HStack(spacing: 16) {
                        DownloadStyleButton(
                            style: .progress,
                            isSelected: selectedDownloadIndicatorStyle == .progress,
                            disabled: !enableDownloadListener
                        ) {
                            selectedDownloadIndicatorStyle = .progress
                        }

                        DownloadStyleButton(
                            style: .circle,
                            isSelected: selectedDownloadIndicatorStyle == .circle,
                            disabled: !enableDownloadListener
                        ) {
                            selectedDownloadIndicatorStyle = .circle
                        }
                    }

                    Text("A bar that fills as the download runs, or a ring around the notch's corner.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .settingsHighlight(id: highlightID("Download indicator style"))

                VStack(alignment: .leading, spacing: 6) {
                    Defaults.Toggle(key: .showDownloadSpeed) {
                        Text("Show download speed")
                    }
                    .disabled(!enableDownloadListener)

                    Text("Adds the current rate beside the indicator, measured from how fast the files in your Downloads folder are growing.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .settingsHighlight(id: highlightID("Show download speed"))
            } header: {
                Text("Download Detection")
            } footer: {
                Text("Shows a live activity in the Dynamic Island while a file is downloading. Works with Safari, Firefox, and Chrome and the browsers built on it — Edge, Brave, Arc, Vivaldi and Opera. Only your Downloads folder is watched, so a file saved anywhere else will not appear.")
            }
        }
        .navigationTitle("Downloads")
    }

    struct DownloadStyleButton: View {
        let style: DownloadIndicatorStyle
        let isSelected: Bool
        let disabled: Bool
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

                    if style == .progress {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .tint(.accentColor)
                            .frame(width: 40)
                    } else {
                        SpinningCircleDownloadView()
                    }
                }
                .frame(width: 80, height: 60)
                .onHover { hovering in
                    if !disabled {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHovering = hovering
                        }
                    }
                }

                Text(style.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 100)
                    .foregroundStyle(disabled ? .secondary : .primary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !disabled {
                    action()
                }
            }
            .opacity(disabled ? 0.5 : 1.0)
        }

        private var backgroundColor: Color {
            if disabled { return Color(nsColor: .controlBackgroundColor) }
            if isSelected { return Color.accentColor.opacity(0.1) }
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

