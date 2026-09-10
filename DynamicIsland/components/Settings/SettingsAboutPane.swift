//
//  SettingsAboutPane.swift
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

struct About: View {
    @State private var showBuildNumber: Bool = false
    @Default(.updateChannel) var updateChannel
    let updaterController: SPUStandardUpdaterController
    @Environment(\.openWindow) var openWindow
    var body: some View {
        VStack {
            Form {
                Section {
                    HStack {
                        Text("Release name")
                        Spacer()
                        Text(Defaults[.releaseName])
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()

                        // Channel badge
                        Text(UpdateChannel.buildChannel.displayName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(UpdateChannel.buildChannel.badgeColor).opacity(0.2))
                            .foregroundStyle(Color(UpdateChannel.buildChannel.badgeColor))
                            .clipShape(Capsule())

                        if showBuildNumber {
                            Text("(\(Bundle.main.buildVersionNumber ?? ""))")
                                .foregroundStyle(.secondary)
                        }
                        Text(Bundle.main.releaseVersionNumber ?? "unkown")
                            .foregroundStyle(.secondary)
                    }
                    .onTapGesture {
                        withAnimation {
                            showBuildNumber.toggle()
                        }
                    }
                } header: {
                    Text("Version info")
                }

                UpdaterSettingsView(updater: updaterController.updater)

                HStack(spacing: 30) {
                    Spacer(minLength: 0)
                    Button {
                        NSWorkspace.shared.open(sponsorPage)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                            Text("Donate")
                                .foregroundStyle(.primary)
                        }
                        .contentShape(Rectangle())
                    }
                    Spacer(minLength: 0)
                    Button {
                        NSWorkspace.shared.open(productPage)
                    } label: {
                        VStack(spacing: 5) {
                            Image("Github")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18)
                                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                            Text("GitHub")
                                .foregroundStyle(.primary)
                        }
                        .contentShape(Rectangle())
                    }
                    Spacer(minLength: 0)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Your support funds software development learning for students in 9th–12th grade.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 5)

                Section {
                    ForEach(UpdateChannel.availableChannels) { channel in
                        Button {
                            updateChannel = channel
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: channel.badgeIcon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(channel.badgeColor))
                                    .frame(width: 20, alignment: .center)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(channel.displayName)
                                        .foregroundStyle(.primary)
                                    Text(channel.description)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if updateChannel == channel {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(channel.badgeColor))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Current build: \(UpdateChannel.buildChannel.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Update channel")
                }
                VStack(spacing: 0) {
                    Divider()
                        .padding(.bottom, 5)
                    Text("Made with ❤️ by Ebullioscopic")
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 7)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .toolbar {
            //            Button("Welcome window") {
            //                openWindow(id: "onboarding")
            //            }
            //            .controlSize(.extraLarge)
            CheckForUpdatesView(updater: updaterController.updater)
        }
        .navigationTitle("About")
    }
}

struct AppIconImage: View {
    let bundleIdentifiers: [String]
    var assetFallback: String? = nil
    var symbolFallback: String = "app.fill"
    var symbolColor: Color = .accentColor
    var size: CGFloat = 16

    var body: some View {
        Group {
            if let nsImage = resolvedIcon() {
                Image(nsImage: nsImage.fitted(toSide: size))
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            } else if let assetFallback, let nsImage = NSImage(named: NSImage.Name(assetFallback)) {
                Image(nsImage: nsImage.fitted(toSide: size))
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            } else {
                Image(systemName: symbolFallback)
                    .foregroundColor(symbolColor)
            }
        }
        .frame(width: size, height: size)
    }

    private func resolvedIcon() -> NSImage? {
        for bundleID in bundleIdentifiers {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                // NSWorkspace returns a valid icon even for generic apps;
                // redraw it small to keep memory low. At twice the size it is
                // asked for, so it stays sharp on a Retina display -- the old
                // flat 32 was being scaled *up* wherever this is drawn larger
                // than that, which is why the bigger icons looked soft.
                let side = max(32, size * 2)
                let thumb = NSImage(size: NSSize(width: side, height: side))
                thumb.lockFocus()
                icon.draw(in: NSRect(origin: .zero, size: NSSize(width: side, height: side)),
                          from: NSRect(origin: .zero, size: icon.size),
                          operation: .copy, fraction: 1.0)
                thumb.unlockFocus()
                return thumb
            }
        }
        return nil
    }
}
