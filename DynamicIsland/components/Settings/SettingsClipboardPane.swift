//
//  SettingsClipboardPane.swift
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

struct ClipboardSettings: View {
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @Default(.enableClipboardManager) var enableClipboardManager
    @Default(.clipboardHistorySize) var clipboardHistorySize
    @Default(.showClipboardIcon) var showClipboardIcon
    @Default(.clipboardDisplayMode) var clipboardDisplayMode

    private func highlightID(_ title: String) -> String {
        SettingsTab.clipboard.highlightID(for: title)
    }

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enableClipboardManager) {
                    Text("Enable Clipboard Manager")
                }
                .settingsHighlight(id: highlightID("Enable Clipboard Manager"))
                .onChange(of: enableClipboardManager) { _, enabled in
                    if enabled {
                        clipboardManager.startMonitoring()
                    } else {
                        clipboardManager.stopMonitoring()
                    }
                }
            } header: {
                Text("Clipboard Manager")
            } footer: {
                if let shortcut = boundShortcutDescription(for: .clipboardHistoryPanel) {
                    Text("Monitor clipboard changes and keep a history of recent copies. Press \(shortcut) to open clipboard history.")
                } else {
                    Text("Monitor clipboard changes and keep a history of recent copies. Set a shortcut under Shortcuts to open clipboard history.")
                }
            }

            if enableClipboardManager {
                Section {
                    Defaults.Toggle(key: .persistClipboardHistory) {
                        Text("Save History Across Restarts")
                    }
                    .settingsHighlight(id: highlightID("Save History Across Restarts"))
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("When off, clipboard history is kept in memory for this session only and is never written to disk. Turning it off also erases history that was already saved. Pinned items are kept either way.")
                }

                Section {
                    Defaults.Toggle(key: .showClipboardIcon) {
                        Text("Show Clipboard Icon")
                    }
                    .settingsHighlight(id: highlightID("Show Clipboard Icon"))

                    HStack {
                        Text("Display Mode")
                        Spacer()
                        Picker("", selection: $clipboardDisplayMode) {
                            ForEach(ClipboardDisplayMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 100)
                    }
                    .settingsHighlight(id: highlightID("Display Mode"))

                    HStack {
                        Text("History Size")
                        Spacer()
                        Picker("", selection: $clipboardHistorySize) {
                            Text("3 items").tag(3)
                            Text("5 items").tag(5)
                            Text("7 items").tag(7)
                            Text("10 items").tag(10)
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 100)
                    }
                    .settingsHighlight(id: highlightID("History Size"))

                    HStack {
                        Text("Current Items")
                        Spacer()
                        Text("\(clipboardManager.clipboardHistory.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Pinned Items")
                        Spacer()
                        Text("\(clipboardManager.pinnedItems.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Monitoring Status")
                        Spacer()
                        Text(clipboardManager.isMonitoring ? "Active" : "Stopped")
                            .foregroundColor(clipboardManager.isMonitoring ? .green : .secondary)
                    }
                } header: {
                    Text("Settings")
                } footer: {
                    switch clipboardDisplayMode {
                    case .popover:
                        Text("Popover mode shows clipboard as a dropdown attached to the clipboard button.")
                    case .panel:
                        Text("Panel mode shows clipboard in a floating window near the notch.")
                    case .separateTab:
                        Text("Separate Tab mode integrates Copied Items and Notes into a single view. If both are enabled, Notes appear on the right and Clipboard on the left.")
                    case .notchTab:
                        Text("Notch Tab mode shows clipboard in its own tab inside the notch. Drag text, image, or single-file items straight out to Finder or another app.")
                    }
                }

                Section {
                    Button("Clear Clipboard History") {
                        clipboardManager.clearHistory()
                    }
                    .foregroundColor(.red)
                    .disabled(clipboardManager.clipboardHistory.isEmpty)

                    Button("Clear Pinned Items") {
                        clipboardManager.clearPinnedItems()
                    }
                    .foregroundColor(.red)
                    .disabled(clipboardManager.pinnedItems.isEmpty)
                } header: {
                    Text("Actions")
                } footer: {
                    Text("Clear clipboard history removes recent copies. Clear pinned items removes your favorites. Both actions are permanent.")
                }

                if !clipboardManager.clipboardHistory.isEmpty {
                    Section {
                        ForEach(clipboardManager.clipboardHistory) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: item.type.icon)
                                        .foregroundColor(.blue)
                                        .frame(width: 16)
                                    Text(item.type.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(timeAgoString(from: item.timestamp))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text(item.preview)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Current History")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Clipboard")
        .onAppear {
            if enableClipboardManager && !clipboardManager.isMonitoring {
                clipboardManager.startMonitoring()
            }
        }
    }

    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

