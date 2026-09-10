//
//  SettingsStatsPane.swift
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

struct StatsSettings: View {
    @ObservedObject var statsManager = StatsManager.shared
    @Default(.enableStatsFeature) var enableStatsFeature
    @Default(.enableLLMUsageFeature) var enableLLMUsageFeature
    @Default(.enableNewAPIProvider) var enableNewAPIProvider
    @Default(.statsStopWhenNotchCloses) var statsStopWhenNotchCloses
    @Default(.statsUpdateInterval) var statsUpdateInterval
    @Default(.showCpuGraph) var showCpuGraph
    @Default(.showMemoryGraph) var showMemoryGraph
    @Default(.showGpuGraph) var showGpuGraph
    @Default(.showNetworkGraph) var showNetworkGraph
    @Default(.showDiskGraph) var showDiskGraph
    @Default(.cpuTemperatureUnit) var cpuTemperatureUnit
    @State private var newAPIAccounts = Defaults[.newAPIAccounts]
    @State private var isNewAPIEditorPresented = false
    @State private var editingNewAPIAccount: NewAPIAccount?
    @State private var accountPendingDeletion: NewAPIAccount?
    @State private var newAPIAccountErrorMessage: String?

    private func highlightID(_ title: String) -> String {
        SettingsTab.stats.highlightID(for: title)
    }

    var enabledGraphsCount: Int {
        [showCpuGraph, showMemoryGraph, showGpuGraph, showNetworkGraph, showDiskGraph].filter { $0 }.count
    }

    private var formattedUpdateInterval: String {
        let seconds = Int(statsUpdateInterval.rounded())
        if seconds >= 60 {
            return "60 s (1 min)"
        } else if seconds == 1 {
            return "1 s"
        } else {
            return "\(seconds) s"
        }
    }

    private var shouldShowStatsBatteryWarning: Bool {
        !statsStopWhenNotchCloses && statsUpdateInterval <= 5
    }

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enableStatsFeature) {
                    Text("Enable system stats monitoring")
                }
                .settingsHighlight(id: highlightID("Enable system stats monitoring"))
                .onChange(of: enableStatsFeature) { _, newValue in
                    if !newValue {
                        statsManager.stopMonitoring()
                    }
                    // Note: Smart monitoring will handle starting when switching to stats tab
                }

                Defaults.Toggle(key: .enableLLMUsageFeature) {
                    Text("Enable LLM Usage Monitor")
                }
                .settingsHighlight(id: highlightID("Enable LLM Usage Monitor"))

            } header: {
                Text("General")
            } footer: {
                Text("When enabled, the Stats tab will display real-time system performance graphs. This feature requires system permissions and may use additional battery. Enabling LLM Usage Monitor adds a Usage tab that tracks token usage and spend across your configured AI providers.")
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            if enableLLMUsageFeature {
                Section {
                    Defaults.Toggle(key: .enableClaudeProvider) {
                        Text("Claude")
                    }
                    .settingsHighlight(id: highlightID("Claude Provider"))

                    Defaults.Toggle(key: .enableCodexProvider) {
                        Text("Codex")
                    }
                    .settingsHighlight(id: highlightID("Codex Provider"))

                    Defaults.Toggle(key: .enableCursorProvider) {
                        Text("Cursor")
                    }
                    .settingsHighlight(id: highlightID("Cursor Provider"))

                    Defaults.Toggle(key: .enableAntigravityProvider) {
                        Text("Antigravity")
                    }
                    .settingsHighlight(id: highlightID("Antigravity Provider"))

                    Defaults.Toggle(key: .enableNewAPIProvider) {
                        Text("New API")
                    }
                    .settingsHighlight(id: highlightID("New API Provider"))
                    .onChange(of: enableNewAPIProvider) { _, _ in
                        LLMUsageManager.shared.refreshAll(force: true)
                    }
                } header: {
                    Text("LLM Providers")
                } footer: {
                    Text("Choose which AI providers appear in the Usage tab.")
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                    .font(.caption)
                }

                Section {
                    if newAPIAccounts.isEmpty {
                        Text("Add one or more New API accounts to monitor their balance and usage.")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(newAPIAccounts) { account in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.name)
                                    Text(account.baseURL)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer()

                                Button {
                                    editingNewAPIAccount = account
                                    isNewAPIEditorPresented = true
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .help("Edit New API account")

                                Button(role: .destructive) {
                                    accountPendingDeletion = account
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help("Delete New API account")
                            }
                        }
                    }

                    Button {
                        editingNewAPIAccount = nil
                        isNewAPIEditorPresented = true
                    } label: {
                        Label("Add New API Account", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .settingsHighlight(id: highlightID("New API Accounts"))
                } header: {
                    Text("New API Accounts")
                } footer: {
                    Text("API keys are stored in the macOS Keychain. Balance and usage are shown in the quota units reported by your New API server.")
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            if enableStatsFeature {
                Section {
                    Defaults.Toggle(key: .statsStopWhenNotchCloses) {
                        Text("Stop monitoring after closing the notch")
                    }
                    .settingsHighlight(id: highlightID("Stop monitoring after closing the notch"))
                    .help("When enabled, stats monitoring stops a few seconds after the notch closes.")

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Update interval")
                            Spacer()
                            Text(formattedUpdateInterval)
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $statsUpdateInterval, in: 1...60, step: 1)
                            .accessibilityLabel("Stats update interval")

                        Text("Controls how often system metrics refresh while monitoring is active.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if shouldShowStatsBatteryWarning {
                        Label {
                            Text("High-frequency updates without a timeout can increase battery usage.")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                    }
                } header: {
                    Text("Monitoring Behavior")
                } footer: {
                    Text("Sampling can continue while the notch is closed when the timeout is disabled.")
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Section {
                    Defaults.Toggle(key: .showCpuGraph) {
                        Text("CPU Usage")
                    }
                    .settingsHighlight(id: highlightID("CPU Usage"))

                    if showCpuGraph {
                        SettingsSegmentedPicker(
                            "Temperature unit",
                            selection: $cpuTemperatureUnit,
                            items: Array(LockScreenWeatherTemperatureUnit.allCases)
                        ) { $0.localizedName }
                        .settingsHighlight(id: highlightID("Temperature unit"))
                    }
                    Defaults.Toggle(key: .showMemoryGraph) {
                        Text("Memory Usage")
                    }
                    .settingsHighlight(id: highlightID("Memory Usage"))
                    Defaults.Toggle(key: .showGpuGraph) {
                        Text("GPU Usage")
                    }
                    .settingsHighlight(id: highlightID("GPU Usage"))
                    Defaults.Toggle(key: .showNetworkGraph) {
                        Text("Network Activity")
                    }
                    .settingsHighlight(id: highlightID("Network Activity"))
                    Defaults.Toggle(key: .showDiskGraph) {
                        Text("Disk I/O")
                    }
                    .settingsHighlight(id: highlightID("Disk I/O"))
                } header: {
                    Text("Graph Visibility")
                } footer: {
                    if enabledGraphsCount >= 4 {
                        Text("With \(enabledGraphsCount) graphs enabled, the Dynamic Island will expand horizontally to accommodate all graphs in a single row.")
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        Text("Each graph can be individually enabled or disabled. Network activity shows download/upload speeds, and disk I/O shows read/write speeds.")
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }

                Section {
                    HStack {
                        Text("Monitoring Status")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(statsManager.isMonitoring ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(statsManager.isMonitoring ? "Active" : "Stopped")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if statsManager.isMonitoring {
                        if showCpuGraph {
                            HStack {
                                Text("CPU Usage")
                                Spacer()
                                Text(statsManager.cpuUsageString)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if showMemoryGraph {
                            HStack {
                                Text("Memory Usage")
                                Spacer()
                                Text(statsManager.memoryUsageString)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if showGpuGraph {
                            HStack {
                                Text("GPU Usage")
                                Spacer()
                                Text(statsManager.gpuUsageString)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if showNetworkGraph {
                            HStack {
                                Text("Network Download")
                                Spacer()
                                Text(String(format: "%.1f MB/s", statsManager.networkDownload))
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("Network Upload")
                                Spacer()
                                Text(String(format: "%.1f MB/s", statsManager.networkUpload))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if showDiskGraph {
                            HStack {
                                Text("Disk Read")
                                Spacer()
                                Text(String(format: "%.1f MB/s", statsManager.diskRead))
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("Disk Write")
                                Spacer()
                                Text(String(format: "%.1f MB/s", statsManager.diskWrite))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Text("Last Updated")
                            Spacer()
                            Text(statsManager.lastUpdated, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Live Performance Data")
                }

                Section {
                    HStack {
                        Button(statsManager.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                            if statsManager.isMonitoring {
                                statsManager.stopMonitoring()
                            } else {
                                statsManager.startMonitoring()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundColor(statsManager.isMonitoring ? .red : .blue)

                        Spacer()

                        Button("Clear Data") {
                            statsManager.clearHistory()
                        }
                        .buttonStyle(.bordered)
                        .disabled(statsManager.isMonitoring)
                    }
                } header: {
                    Text("Controls")
                }
            }
        }
        .navigationTitle("Stats")
        .onAppear {
            newAPIAccounts = Defaults[.newAPIAccounts]
        }
        .sheet(isPresented: $isNewAPIEditorPresented) {
            NewAPIAccountEditor(account: editingNewAPIAccount) { account, apiKey in
                try NewAPIAccountStore.upsert(account, apiKey: apiKey)
                newAPIAccounts = Defaults[.newAPIAccounts]
                LLMUsageManager.shared.refreshAll(force: true)
                isNewAPIEditorPresented = false
            }
        }
        .confirmationDialog(
            "Delete New API account?",
            isPresented: Binding(
                get: { accountPendingDeletion != nil },
                set: { if !$0 { accountPendingDeletion = nil } }
            ),
            presenting: accountPendingDeletion
        ) { account in
            Button("Delete \(account.name)", role: .destructive) {
                do {
                    try NewAPIAccountStore.delete(account)
                    newAPIAccounts = Defaults[.newAPIAccounts]
                    LLMUsageManager.shared.refreshAll(force: true)
                    accountPendingDeletion = nil
                } catch {
                    newAPIAccountErrorMessage = "Failed to delete \(account.name): \(error.localizedDescription)"
                }
            }
            Button("Cancel", role: .cancel) {
                accountPendingDeletion = nil
            }
        } message: { account in
            Text("This removes \(account.name) and its stored API key from Atoll.")
        }
        .alert("New API Account Error", isPresented: Binding(
            get: { newAPIAccountErrorMessage != nil },
            set: { if !$0 { newAPIAccountErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { newAPIAccountErrorMessage = nil }
        } message: {
            Text(newAPIAccountErrorMessage ?? "An unknown error occurred.")
        }
    }
}

private struct NewAPIAccountEditor: View {
    let account: NewAPIAccount?
    let onSave: (NewAPIAccount, String) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var baseURL: String
    @State private var apiKey: String
    @State private var errorMessage: String?

    init(account: NewAPIAccount?, onSave: @escaping (NewAPIAccount, String) throws -> Void) {
        self.account = account
        self.onSave = onSave
        _name = State(initialValue: account?.name ?? "")
        _baseURL = State(initialValue: account?.baseURL ?? "https://")
        _apiKey = State(initialValue: account.map { NewAPIKeychain.read(accountID: $0.id) ?? "" } ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(account == nil ? "Add New API Account" : "Edit New API Account")
                .font(.title3.weight(.semibold))

            Form {
                TextField("Account name", text: $name)
                TextField("Base URL", text: $baseURL)
                    .textContentType(.URL)
                SecureField("API key", text: $apiKey)
                    .textContentType(.password)
            }
            .formStyle(.grouped)
            .frame(width: 420)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 470)
    }

    private func save() {
        let updated = NewAPIAccount(
            id: account?.id ?? UUID(),
            name: name,
            baseURL: baseURL
        )
        do {
            try onSave(updated, apiKey)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
