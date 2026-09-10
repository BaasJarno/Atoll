//
//  SettingsShelfPane.swift
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

struct Shelf: View {
    @Default(.quickShareProvider) var quickShareProvider
    @Default(.expandedDragDetection) var expandedDragDetection
    @Default(.copyOnDrag) var copyOnDrag
    @Default(.autoRemoveShelfItems) var autoRemoveShelfItems
    @StateObject private var quickShareService = QuickShareService.shared
    @ObservedObject private var fullDiskAccessPermission = FullDiskAccessPermissionStore.shared
    @ObservedObject private var shelfFolderAccessPermission = ShelfFolderAccessPermissionStore.shared

    private var hasDocumentsAndDownloadsAccess: Bool {
        shelfFolderAccessPermission.hasDocumentsAndDownloadsAccess
    }

    private var canEnableShelf: Bool {
        fullDiskAccessPermission.isAuthorized || hasDocumentsAndDownloadsAccess
    }

    private var selectedProvider: QuickShareProvider? {
        quickShareService.availableProviders.first(where: { $0.id == quickShareProvider })
    }

    init() {
        QuickShareService.shared.ensureDiscovered()
    }

    private func highlightID(_ title: String) -> String {
        SettingsTab.shelf.highlightID(for: title)
    }

    var body: some View {
        Form {
            if !canEnableShelf || !fullDiskAccessPermission.isAuthorized {
                Section {
                    if !canEnableShelf {
                        SettingsPermissionCallout(
                            title: "Additional folder access required",
                            message: "Enable Full Disk Access, or grant access to both Documents and Downloads folders to use Shelf.",
                            icon: "folder.badge.questionmark",
                            iconColor: .orange,
                            requestButtonTitle: "Request Folder Access",
                            openSettingsButtonTitle: "Open Privacy & Security",
                            requestAction: { shelfFolderAccessPermission.requestAccessPrompt() },
                            openSettingsAction: { shelfFolderAccessPermission.openSystemSettings() }
                        )
                    }

                    if !fullDiskAccessPermission.isAuthorized {
                        SettingsPermissionCallout(
                            title: "Full Disk Access for global mode",
                            message: "Without Full Disk Access, Shelf can only read files from Documents and Downloads. Grant Full Disk Access to make Shelf work globally.",
                            icon: "externaldrive.fill",
                            iconColor: .purple,
                            requestButtonTitle: "Request Full Disk Access",
                            openSettingsButtonTitle: "Open Privacy & Security",
                            requestAction: { fullDiskAccessPermission.requestAccessPrompt() },
                            openSettingsAction: { fullDiskAccessPermission.openSystemSettings() }
                        )
                    }
                } header: {
                    Text("Permissions")
                }
            }

            Section {
                Defaults.Toggle(key: .dynamicShelf) {
                    Text("Enable shelf")
                }
                .disabled(!canEnableShelf)
                .settingsHighlight(id: highlightID("Enable shelf"))

                Defaults.Toggle(key: .openShelfByDefault) {
                    Text("Open shelf tab by default if items added")
                }
                .settingsHighlight(id: highlightID("Open shelf tab by default if items added"))

                Defaults.Toggle(key: .expandedDragDetection) {
                    Text("Expanded drag detection area")
                }
                .settingsHighlight(id: highlightID("Expanded drag detection area"))

                Defaults.Toggle(key: .copyOnDrag) {
                    Text("Copy items on drag")
                }
                .settingsHighlight(id: highlightID("Copy items on drag"))

                Defaults.Toggle(key: .allowMoveOnDrag) {
                    Text("Allow moving files when dragging out")
                }
                .settingsHighlight(id: highlightID("Allow moving files when dragging out"))

                Defaults.Toggle(key: .autoRemoveShelfItems) {
                    Text("Remove from shelf after dragging")
                }
                .settingsHighlight(id: highlightID("Remove from shelf after dragging"))
            } header: {
                HStack {
                    Text("General")
                }
            }

            Section {
                Picker("Quick Share Service", selection: $quickShareProvider) {
                    ForEach(quickShareService.availableProviders, id: \.id) { provider in
                        HStack {
                            QuickShareProviderIconImage(provider: provider, size: 16)
                            Text(provider.id)
                        }
                        .tag(provider.id)
                    }
                }
                .pickerStyle(.menu)
                .settingsHighlight(id: highlightID("Quick Share Service"))

                if let selectedProvider {
                    HStack {
                        QuickShareProviderIconImage(provider: selectedProvider, size: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Currently selected: \(selectedProvider.id)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Files dropped on the shelf will be shared via this service")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                HStack {
                    Text("Quick Share")
                }
            } footer: {
                Text("Choose which service to use when sharing files from the shelf. Drag files onto the shelf or click the shelf button to pick files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if quickShareProvider == "LocalSend" {
                LocalSendSettingsSection(highlightID: highlightID)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Shelf")
        .onAppear {
            fullDiskAccessPermission.refreshStatus()
            shelfFolderAccessPermission.refreshStatus()
        }
    }
}

// MARK: - LocalSend Settings Section

private struct LocalSendSettingsSection: View {
    let highlightID: (String) -> String
    
    @Default(.localSendDevicePickerGlassMode) private var glassMode
    @Default(.localSendDevicePickerLiquidGlassVariant) private var liquidGlassVariant
    
    var body: some View {
        Section {
            Picker("Device Picker Style", selection: $glassMode) {
                ForEach(LockScreenGlassCustomizationMode.allCases) { mode in
                    Text(mode.localizedName).tag(mode)
                }
            }
            .pickerStyle(.menu)
            
            if glassMode == .customLiquid {
                Picker("Liquid Glass Variant", selection: $liquidGlassVariant) {
                    ForEach(LiquidGlassVariant.allCases) { variant in
                        Text("Variant \(variant.rawValue)").tag(variant)
                    }
                }
                .pickerStyle(.menu)
            }
        } header: {
            Text("LocalSend Device Picker")
        } footer: {
            Text("Customize the appearance of the LocalSend device selection popup that appears when you drop files.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct QuickShareProviderIconImage: View {
    let provider: QuickShareProvider
    var size: CGFloat = 16

    var body: some View {
        Group {
            if let imgData = provider.imageData, let nsImg = NSImage(data: imgData) {
                Image(nsImage: nsImg.fitted(toSide: size))
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            } else {
                AppIconImage(
                    bundleIdentifiers: provider.bundleIdentifiersFallback,
                    assetFallback: provider.assetFallbackName,
                    symbolFallback: provider.symbolFallbackName,
                    symbolColor: .accentColor,
                    size: size
                )
            }
        }
        .frame(width: size, height: size)
    }
}

private extension QuickShareProvider {
    var bundleIdentifiersFallback: [String] {
        switch id {
        case "LocalSend":
            return ["org.localsend.localsend_app", "org.localsend.localsend"]
        case "AirDrop":
            return ["com.apple.finder"]
        case "Mail":
            return ["com.apple.mail"]
        case "Messages":
            return ["com.apple.MobileSMS", "com.apple.iChat"]
        case "Notes":
            return ["com.apple.Notes"]
        case "Reminders":
            return ["com.apple.reminders"]
        case "Add to Safari Reading List":
            return ["com.apple.Safari"]
        default:
            return []
        }
    }

    var assetFallbackName: String? {
        id == "LocalSend" ? "LocalSend" : nil
    }

    var symbolFallbackName: String {
        id == "System Share Menu" ? "square.and.arrow.up.on.square" : "square.and.arrow.up"
    }
}

