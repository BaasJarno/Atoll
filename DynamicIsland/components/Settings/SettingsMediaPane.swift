//
//  SettingsMediaPane.swift
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

private struct MusicSourceSelector: View {
    @Binding var selection: MediaControllerType
    let controllers: [MediaControllerType]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(controllers) { controller in
                        MusicSourceCard(
                            controller: controller,
                            isSelected: selection == controller
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selection = controller
                            }
                        }
                        .id(controller)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 3)
            }
            .onAppear {
                proxy.scrollTo(selection, anchor: .center)
            }
            .onChange(of: selection) { _, controller in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(controller, anchor: .center)
                }
            }
        }
        .frame(height: 112)
    }
}

private struct MusicSourceCard: View {
    let controller: MediaControllerType
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                // Every source shows the app's own icon, so the row does not
                // mix real icons for the apps we happen to ship a logo for
                // with flat brand marks for the rest. The bundled logo is the
                // fallback for when the app is not installed, which is better
                // than the generic symbol that used to stand in there.
                AppIconImage(
                    bundleIdentifiers: controller.applicationBundleIdentifiers,
                    assetFallback: controller.officialLogoAssetName,
                    symbolFallback: controller.fallbackSymbol,
                    symbolColor: controller.fallbackColor,
                    size: 42
                )
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 42, height: 42)

                Text(controller.localizedName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: 112, height: 92)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(backgroundColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 2.5 : 1)
            }
            .scaleEffect(isHovering && !isSelected ? 1.015 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .accessibilityLabel(controller.localizedName)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.16)
        }
        if isHovering {
            return Color(nsColor: .controlBackgroundColor).opacity(0.92)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.7)
    }

    private var borderColor: Color {
        if isSelected {
            return .accentColor
        }
        return Color(nsColor: .separatorColor).opacity(isHovering ? 0.8 : 0.45)
    }
}

private extension MediaControllerType {
    var officialLogoAssetName: String? {
        switch self {
        case .youtubeMusic: return "YouTubeMusicLogo"
        case .amazonMusic: return "AmazonMusicLogo"
        case .tidal: return "TidalLogo"
        case .cider: return "CiderLogo"
        default: return nil
        }
    }

    var applicationBundleIdentifiers: [String] {
        switch self {
        case .nowPlaying:
            return []
        case .appleMusic:
            return ["com.apple.Music"]
        case .spotify:
            return ["com.spotify.client"]
        case .youtubeMusic:
            return ["com.github.th-ch.youtube-music"]
        case .amazonMusic:
            return ["com.amazon.music"]
        case .tidal:
            return [TidalController.bundleIdentifier]
        case .cider:
            return ["sh.cider.genten.mac"]
        }
    }

    var fallbackSymbol: String {
        switch self {
        case .nowPlaying: return "waveform"
        case .appleMusic: return "music.note"
        case .spotify: return "dot.radiowaves.left.and.right"
        case .youtubeMusic: return "play.rectangle.fill"
        case .amazonMusic: return "music.note.list"
        case .tidal: return "waveform.path"
        case .cider: return "cup.and.saucer.fill"
        }
    }

    var fallbackColor: Color {
        switch self {
        case .nowPlaying: return .accentColor
        case .appleMusic: return .pink
        case .spotify: return .green
        case .youtubeMusic: return .red
        case .amazonMusic: return .cyan
        case .tidal: return .primary
        case .cider: return .orange
        }
    }
}

struct Media: View {
    @Default(.waitInterval) var waitInterval
    @Default(.mediaController) var mediaController
    @ObservedObject var coordinator = DynamicIslandViewCoordinator.shared
    @Default(.hideNotchOption) var hideNotchOption
    @Default(.enableSneakPeek) private var enableSneakPeek
    @Default(.sneakPeekStyles) var sneakPeekStyles
    @Default(.enableMinimalisticUI) var enableMinimalisticUI
    @Default(.showShuffleAndRepeat) private var showShuffleAndRepeat
    @Default(.showMediaOutputControl) private var showMediaOutputControl
    @Default(.musicSkipBehavior) private var musicSkipBehavior
    @Default(.musicControlWindowEnabled) private var musicControlWindowEnabled
    @Default(.enableLockScreenMediaWidget) private var enableLockScreenMediaWidget
    @Default(.showSneakPeekOnTrackChange) private var showSneakPeekOnTrackChange
    @Default(.lockScreenGlassStyle) private var lockScreenGlassStyle
    @Default(.lockScreenGlassCustomizationMode) private var lockScreenGlassCustomizationMode
    @Default(.lockScreenMusicAlbumParallaxEnabled) private var lockScreenMusicAlbumParallaxEnabled
    @Default(.lockScreenMusicFullscreenArtworkEnabled) private var lockScreenMusicFullscreenArtworkEnabled
    @Default(.showStandardMediaControls) private var showStandardMediaControls
    @Default(.autoHideInactiveNotchMediaPlayer) private var autoHideInactiveNotchMediaPlayer
    @Default(.showCalendar) private var showCalendar
    @Default(.enableLyrics) private var enableLyrics
    @Default(.lyricHighlightStyle) private var lyricHighlightStyle
    @Default(.lyricsPanelWidth) private var lyricsPanelWidth
    @Default(.lyricsPanelOffset) private var lyricsPanelOffset
    @Default(.visualizerBarCount) private var visualizerBarCount
    @Default(.enableWaveformScrubber) private var enableWaveformScrubber
    @Default(.colorExtractionMode) private var colorExtractionMode
    @Default(.parallaxEffectIntensity) private var parallaxEffectIntensity

    
    @ObservedObject private var musicManager = MusicManager.shared

    private var isAppleMusicActive: Bool {
        musicManager.bundleIdentifier == "com.apple.Music"
    }

    private func highlightID(_ title: String) -> String {
        SettingsTab.media.highlightID(for: title)
    }

    private var standardControlsSuppressed: Bool {
        !showStandardMediaControls && !enableMinimalisticUI
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Text("Music Source")
                            .font(.system(size: 13, weight: .semibold))
                        MediaSourceCapabilitiesButton(controllers: availableMediaControllers)
                        Spacer()
                        ScrollHintIndicator()
                    }

                    MusicSourceSelector(
                        selection: $mediaController,
                        controllers: availableMediaControllers
                    )
                }
                .onChange(of: mediaController) { _, _ in
                    NotificationCenter.default.post(
                        name: Notification.Name.mediaControllerChanged,
                        object: nil
                    )
                }
                .settingsHighlight(id: highlightID("Music Source"))
            } header: {
                Text("Media Source")
            } footer: {
                if MusicManager.shared.isNowPlayingDeprecated {
                    HStack {
                        Text("YouTube Music requires this third-party app to be installed: ")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Link("https://github.com/th-ch/youtube-music", destination: URL(string: "https://github.com/th-ch/youtube-music")!)
                            .font(.caption)
                            .foregroundColor(.blue) // Ensures it's visibly a link
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "'Now Playing' was the only option on previous versions and works with all media apps."))
                        if mediaController == .amazonMusic || mediaController == .tidal || mediaController == .cider {
                            Text(mediaController.description)
                        }
                    }
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }

            if mediaController == .spotify {
                SpotifyAuthSettingsSection()
                SpotifyLikeButtonSettingsSection()
            }

            if mediaController == .cider {
                CiderFavoritingSettingsSection()
            }

            Section {
                Defaults.Toggle(key: .showStandardMediaControls) {
                    Text("Show media controls in Dynamic Island")
                }
                .disabled(enableMinimalisticUI)
                .settingsHighlight(id: highlightID("Show media controls in Dynamic Island"))

                Defaults.Toggle(key: .autoHideInactiveNotchMediaPlayer) {
                    Text("Auto-hide inactive notch media player")
                }
                .disabled(enableMinimalisticUI || !showStandardMediaControls)
                .settingsHighlight(id: highlightID("Auto-hide inactive notch media player"))

                if enableMinimalisticUI {
                    Text("Disable Minimalistic UI to configure the standard notch media controls.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if standardControlsSuppressed {
                    Text("Standard notch media controls are hidden. Re-enable the toggle above to restore them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !autoHideInactiveNotchMediaPlayer {
                    Text("When disabled, the notch music player stays visible with placeholder metadata even when playback is inactive.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Dynamic Island Visibility")
            }
            Section {
                Defaults.Toggle(key: .showShuffleAndRepeat) {
                    HStack {
                        Text("Enable customizable controls")
                        customBadge(text: "Beta")
                    }
                }
                if showShuffleAndRepeat {
                    Defaults.Toggle(key: .showMediaOutputControl) {
                        Text("Show \"Change Media Output\" control")
                    }
                    .settingsHighlight(id: highlightID("Show Change Media Output control"))
                    .help("Adds the AirPlay/route picker button back to the customizable controls palette. The lock screen panel also uses this button for its volume slider, so turning it off leaves that panel with no volume control.")
                    MusicSlotConfigurationView()
                } else {
                    Text("Turn on customizable controls to rearrange media buttons.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }
            } header: {
                Text("Media controls")
            }

            Section(header: Text("Lock Screen Media")) {
                Defaults.Toggle(key: .lockScreenMusicAlbumParallaxEnabled) {
                    Text("Enable album art parallax")
                }
                .settingsHighlight(id: highlightID("Enable album art parallax"))
                Text("Applies the notch-style parallax effect to the lock screen media widget album art.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Defaults.Toggle(key: .alwaysShowLockScreenVolume) {
                        Text("Always show volume control")
                    }
                    .disabled(!showMediaOutputControl)
                    Text(showMediaOutputControl
                         ? "Keeps a volume slider under the playback controls on the lock screen, instead of leaving it behind the output button. The volume keys move it while the Mac is locked, where the notch cannot draw. Also on the Lock Screen tab."
                         : "Needs the \"Change Media Output\" control above, which the lock screen panel takes its volume slider from.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .settingsHighlight(id: highlightID("Always show volume control"))
            }
            Section {
                SettingsSegmentedPicker(
                    "Skip buttons",
                    selection: $musicSkipBehavior,
                    items: Array(MusicSkipBehavior.allCases)
                ) { $0.displayName }
                .settingsHighlight(id: highlightID("Skip buttons"))

                Text(musicSkipBehavior.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Skip button behaviour")
            } footer: {
                Text("Applies everywhere the transport controls appear: the notch player, the lock screen panel, and the floating window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle(
                    "Enable music live activity",
                    isOn: $coordinator.musicLiveActivityEnabled.animation()
                )
                .disabled(standardControlsSuppressed)
                .help(standardControlsSuppressed ? "Standard notch media controls are hidden while this toggle is off." : "")
                Defaults.Toggle(key: .musicControlWindowEnabled) {
                    Text("Show floating media controls")
                }
                .disabled(!coordinator.musicLiveActivityEnabled || standardControlsSuppressed)
                .help("Displays play/pause and skip buttons beside the notch while music is active. Disabled by default.")
                Toggle("Enable sneak peek", isOn: $enableSneakPeek)
                Toggle("Show sneak peek on playback changes", isOn: $showSneakPeekOnTrackChange)
                    .disabled(!enableSneakPeek)
                Defaults.Toggle(key: .enableLyrics) {
                    Text("Show lyrics")
                }
                .disabled(enableMinimalisticUI || !showStandardMediaControls)
                .opacity(enableMinimalisticUI || !showStandardMediaControls ? 0.5 : 1)
                .help(
                    enableMinimalisticUI
                        ? "Disable Minimalistic UI to show lyrics."
                        : !showStandardMediaControls
                            ? "Enable Dynamic Island media controls to show lyrics."
                            : ""
                )
                .settingsHighlight(id: highlightID("Show lyrics"))

                if enableLyrics && !enableMinimalisticUI && showStandardMediaControls {
                    // Caption inside the row rather than after it: a Form gives
                    // every top-level view its own row and a divider, so the
                    // explanation was being ruled off from the control it
                    // explains and read as belonging to nothing.
                    VStack(alignment: .leading, spacing: 6) {
                        SettingsSegmentedPicker(
                            "Highlight",
                            selection: $lyricHighlightStyle,
                            items: Array(LyricHighlightStyle.allCases)
                        ) { $0.localizedName }

                        Text(lyricHighlightStyle.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .settingsHighlight(id: highlightID("Lyric highlight"))
                }

                if enableLyrics && !enableMinimalisticUI && showStandardMediaControls {
                    Defaults.Toggle(key: .pinLyricsWhenClosed) {
                        Text("Keep lyrics under the closed notch")
                    }
                    .settingsHighlight(id: highlightID("Keep lyrics under the closed notch"))

                    Text("Shows the line currently being sung below the notch while it is closed, so lyrics stay readable without hovering. Can also be toggled from the pin on the lyrics panel. Hidden while a HUD is on screen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(
                    showCalendar
                        ? "Lyrics sit on one line under the artist name, since the calendar is using the rest of the notch. Turn the calendar off to give them a full panel beside the player."
                        : "Lyrics get their own panel beside the player. Turn the calendar on to move them under the artist name instead."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                if enableMinimalisticUI {
                    Text("Disable Minimalistic UI to use lyrics.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !showStandardMediaControls {
                    Text("Enable Dynamic Island media controls to use lyrics.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if enableLyrics && !enableMinimalisticUI && !showCalendar && showStandardMediaControls {
                    Slider(value: $lyricsPanelWidth, in: 180...420, step: 10) {
                        HStack {
                            Text("Side lyrics width")
                            Spacer()
                            Text("\(Int(lyricsPanelWidth)) px")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .settingsHighlight(id: highlightID("Side lyrics width"))

                    Slider(value: $lyricsPanelOffset, in: -100...100, step: 1) {
                        HStack {
                            Text("Side lyrics horizontal offset")
                            Spacer()
                            Text("\(lyricsPanelOffset >= 0 ? "+" : "")\(Int(lyricsPanelOffset)) px")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .settingsHighlight(id: highlightID("Side lyrics horizontal offset"))

                    Text("These controls apply when the calendar is disabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Defaults.Toggle(key: .showLiveCanvasInDynamicIsland) {
                    Text("Show live canvas in Dynamic Island")
                }
                .settingsHighlight(id: highlightID("Show live canvas in Dynamic Island"))
                .help("Replaces the artwork tile with the live canvas when the current app provides one, and reuses that moving canvas for the surrounding lighting effect.")
                
                //Parallax Effect Intensity to control how much parallax is wanted
                Slider(value: $parallaxEffectIntensity, in: 0...12, step: 1.0) {
                    HStack {
                        Text("Parallax Effect Intensity")
                        Spacer()
                        Text("\(parallaxEffectIntensity, specifier: "%0.1f")")
                            .foregroundStyle(.secondary)
                    }
                }
                .settingsHighlight(id: highlightID("Enable album art parallax effect"))
                
                Picker("Sneak Peek Style", selection: $sneakPeekStyles){
                    ForEach(SneakPeekStyle.allCases) { style in
                        Text(style.localizedName).tag(style)
                    }
                }
                .disabled(!enableSneakPeek)
                .settingsHighlight(id: highlightID("Sneak Peek Style"))

                HStack {
                    Stepper(value: $waitInterval, in: 0...10, step: 1) {
                        HStack {
                            Text("Media inactivity timeout")
                            Spacer()
                            Text("\(Defaults[.waitInterval], specifier: "%.0f") seconds")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Defaults.Toggle(key: .showSongMetadataInClosedNotch) {
                    Text("Show song title and artist on non-notch displays")
                }
                .settingsHighlight(id: highlightID("Show song title and artist in closed notch"))
            } header: {
                Text("Media playback live activity")
            }

            Section {
                Defaults.Toggle(key: .enableRealTimeWaveform) {
                    HStack {
                        Text("Enable real-time waveform")
                        customBadge(text: "Beta")
                    }
                }
                .settingsHighlight(id: highlightID("Enable real-time waveform"))
                
                Picker("Visualizer candles", selection: $visualizerBarCount) {
                    Text("4").tag(4)
                    Text("5").tag(5)
                    Text("6").tag(6)
                }
                
                Picker("Color extraction", selection: $colorExtractionMode) {
                    Text("Legacy").tag(ColorExtractionMode.legacy)
                    Text("Vibrant").tag(ColorExtractionMode.vibrant)
                }
                
                Toggle("Scrubbable real-time waveform", isOn: $enableWaveformScrubber)
            } header: {
                Text("Music Visualizer")
            } footer: {
                Text("When enabled, the music visualizer displays real-time audio spectrum data synced to your music. Requires macOS 14.2+ and uses minimal CPU/GPU resources via the Accelerate framework.")
            }

            Section {
                Defaults.Toggle(key: .enableLockScreenMediaWidget) {
                    Text("Show lock screen media panel")
                }
                Defaults.Toggle(key: .lockScreenShowAppIcon) {
                    Text("Show media app icon")
                }
                .disabled(!enableLockScreenMediaWidget)
                if isAppleMusicActive {
                    Defaults.Toggle(key: .lockScreenMusicMergedAirPlayOutput) {
                        Text("Show merged AirPlay and output devices")
                    }
                    .disabled(!enableLockScreenMediaWidget)
                    .settingsHighlight(id: highlightID("Show merged AirPlay and output devices"))
                }
                Defaults.Toggle(key: .lockScreenPanelShowsBorder) {
                    Text("Show panel border")
                }
                .disabled(!enableLockScreenMediaWidget)

                // Deliberately the same setting as the one on the Media tab.
                // It is one key, so the two cannot drift; it is on both because
                // this is a lock screen setting, while the control it depends
                // on lives over on Media.
                VStack(alignment: .leading, spacing: 6) {
                    Defaults.Toggle(key: .alwaysShowLockScreenVolume) {
                        Text("Always show volume control")
                    }
                    .disabled(!enableLockScreenMediaWidget || !showMediaOutputControl)
                    Text(showMediaOutputControl
                         ? "Keeps a volume slider under the playback controls on the lock screen, instead of leaving it behind the output button. The volume keys move it while the Mac is locked, where the notch cannot draw."
                         : "Needs the \"Show Change Media Output control\" setting on the Media tab, which the lock screen panel takes its volume slider from.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .settingsHighlight(id: highlightID("Always show volume control"))
                if lockScreenGlassCustomizationMode == .customLiquid {
                    Defaults.Toggle(key: .lockScreenMusicUsesEnhancedLiquidBorder) {
                        Text("Use enhanced liquid border")
                    }
                    .disabled(!enableLockScreenMediaWidget)
                }
                if lockScreenGlassCustomizationMode == .customLiquid {
                    customLiquidBlurRow
                        .opacity(enableLockScreenMediaWidget ? 1 : 0.5)
                        .settingsHighlight(id: highlightID("Enable media panel blur"))
                } else if lockScreenGlassStyle == .frosted {
                    Defaults.Toggle(key: .lockScreenPanelUsesBlur) {
                        Text("Enable media panel blur")
                    }
                    .disabled(!enableLockScreenMediaWidget)
                    .settingsHighlight(id: highlightID("Enable media panel blur"))
                } else {
                    unavailableBlurRow
                        .opacity(enableLockScreenMediaWidget ? 1 : 0.5)
                        .settingsHighlight(id: highlightID("Enable media panel blur"))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Defaults.Toggle(key: .lockScreenMusicFullscreenArtworkEnabled) {
                        Text("Fullscreen artwork on right-click")
                    }
                    .disabled(!enableLockScreenMediaWidget)
                    .settingsHighlight(id: highlightID("Fullscreen artwork on right-click"))
                    Defaults.Toggle(key: .lockScreenUseArtworkLayoutOverFullscreenCanvas) {
                        Text("Use album art layout over fullscreen canvas")
                    }
                    .disabled(!enableLockScreenMediaWidget || !lockScreenMusicFullscreenArtworkEnabled)
                    .settingsHighlight(id: highlightID("Use album art layout over fullscreen canvas"))
                    Defaults.Toggle(key: .lockScreenKeepAlbumArtVisibleDuringFullscreenArtwork) {
                        Text("Keep album art visible during fullscreen artwork")
                    }
                    .disabled(!enableLockScreenMediaWidget || !lockScreenMusicFullscreenArtworkEnabled)
                    .settingsHighlight(id: highlightID("Keep album art visible during fullscreen artwork"))
                    Text("Right-click the album art on the lock screen to set it as the wallpaper. Right-click again or click the background to restore the original wallpaper. If a canvas is available, Atoll can also keep the same album art + player layout on top of the live canvas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text("Lock Screen Integration")
            } footer: {
                Text("These controls mirror the Lock Screen tab so you can tune the media overlay while focusing on playback settings.")
            }
            .disabled(!showStandardMediaControls)
            .opacity(showStandardMediaControls ? 1 : 0.5)

            Picker(selection: $hideNotchOption, label:
                    HStack {
                Text("Hide DynamicIsland Options")
                customBadge(text: "Beta")
            }) {
                Text("Always hide in fullscreen").tag(HideNotchOption.always)
                Text("Hide only when NowPlaying app is in fullscreen").tag(HideNotchOption.nowPlayingOnly)
                Text("Never hide").tag(HideNotchOption.never)
            }
            .onChange(of: hideNotchOption) {
                Defaults[.enableFullscreenMediaDetection] = hideNotchOption != .never
            }
        }
        .navigationTitle("Media")
    }

    // Only show controller options that are available on this macOS version
    private var availableMediaControllers: [MediaControllerType] {
        if MusicManager.shared.isNowPlayingDeprecated {
            return MediaControllerType.allCases.filter { $0 != .nowPlaying }
        } else {
            return MediaControllerType.allCases
        }
    }

    private var unavailableBlurRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Enable media panel blur")
                .foregroundStyle(.secondary)
            Text("Only applies when Material is set to Frosted Glass.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var customLiquidBlurRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Enable media panel blur")
                .foregroundStyle(.secondary)
            Text("Custom liquid glass already renders with Apple's liquid material, so this option is managed automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

