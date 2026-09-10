//
//  SettingsShell.swift
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

/// Groups for organizing settings tabs in the sidebar.
enum SettingsTabGroup: String, CaseIterable, Identifiable {
    case core
    case mediaAndDisplay
    case system
    case productivity
    case utilities
    case developer
    case integrations
    case info

    var id: String { rawValue }

    /// Display title for the section header.  `nil` means no visible header.
    var title: String? {
        switch self {
        case .core:             return nil
        case .mediaAndDisplay:  return String(localized: "Media & Display")
        case .system:           return String(localized: "System")
        case .productivity:     return String(localized: "Productivity")
        case .utilities:        return String(localized: "Utilities")
        case .developer:        return String(localized: "Developer")
        case .integrations:     return String(localized: "Integrations")
        case .info:             return nil
        }
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case liveActivities
    case appearance
    case lockScreen
    case media
    case devices
    case extensions
    case timer
    case calendar
    case hudAndOSD
    case battery
    case stats
    case clipboard
    case screenAssistant
    case colorPicker
    case downloads
    case shelf
    case shortcuts
    case notes
    case terminal
    case about

    var id: String { rawValue }

    /// Which sidebar group this tab belongs to.
    var group: SettingsTabGroup {
        switch self {
        case .general, .appearance:                                          return .core
        case .media, .liveActivities, .lockScreen, .devices:                 return .mediaAndDisplay
        case .hudAndOSD, .battery:                                           return .system
        case .timer, .calendar, .notes:                                      return .productivity
        case .clipboard, .screenAssistant, .colorPicker, .shelf,
             .downloads, .shortcuts:                                         return .utilities
        case .stats, .terminal:                                              return .developer
        case .extensions:                                                    return .integrations
        case .about:                                                         return .info
        }
    }

    var title: String {
        switch self {
        case .general: return String(localized: "General")
        case .liveActivities: return String(localized: "Live Activities")
        case .appearance: return String(localized: "Appearance")
        case .lockScreen: return String(localized: "Lock Screen")
        case .media: return String(localized: "Media")
        case .devices: return String(localized: "Devices")
        case .extensions: return String(localized: "Extensions")
        case .timer: return String(localized: "Timer")
        case .calendar: return String(localized: "Calendar")
        case .hudAndOSD: return String(localized: "Controls")
        case .battery: return String(localized: "Battery")
        case .stats: return String(localized: "Stats")
        case .clipboard: return String(localized: "Clipboard")
        case .screenAssistant: return String(localized: "Screen Assistant")
        case .colorPicker: return String(localized: "Color Picker")
        case .downloads: return String(localized: "Downloads")
        case .shelf: return String(localized: "Shelf")
        case .shortcuts: return String(localized: "Shortcuts")
        case .notes: return String(localized: "Notes")
        case .terminal: return String(localized: "Terminal")
        case .about: return String(localized: "About")
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gear"
        case .liveActivities: return "waveform.path.ecg"
        case .appearance: return "paintpalette"
        case .lockScreen: return "lock.laptopcomputer"
        case .media: return "play.laptopcomputer"
        case .devices: return "headphones"
        case .extensions: return "puzzlepiece.extension"
        case .timer: return "timer"
        case .calendar: return "calendar"
        case .hudAndOSD: return "dial.medium.fill"
        case .battery: return "battery.100.bolt"
        case .stats: return "chart.xyaxis.line"
        case .clipboard: return "clipboard"
        case .screenAssistant: return "brain.head.profile"
        case .colorPicker: return "eyedropper"
        case .downloads: return "square.and.arrow.down"
        case .shelf: return "books.vertical"
        case .shortcuts: return "keyboard"
        case .notes: return "note.text"
        case .terminal: return "apple.terminal"
        case .about: return "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .general: return .blue
        case .liveActivities: return .pink
        case .appearance: return .purple
        case .lockScreen: return .orange
        case .media: return .green
        case .devices: return Color(red: 0.1, green: 0.11, blue: 0.12)
        case .extensions: return Color(red: 0.557, green: 0.353, blue: 0.957)
        case .timer: return .red
        case .calendar: return .cyan
        case .hudAndOSD: return .indigo
        case .battery: return Color(red: 0.202, green: 0.783, blue: 0.348, opacity: 1.000)
        case .stats: return .teal
        case .clipboard: return .mint
        case .screenAssistant: return .pink
        case .colorPicker: return .accentColor
        case .downloads: return .gray
        case .shelf: return .brown
        case .shortcuts: return .orange
        case .notes: return Color(red: 0.979, green: 0.716, blue: 0.153, opacity: 1.000)
        case .terminal: return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .about: return .secondary
        }
    }

    func highlightID(for title: String) -> String {
        "\(rawValue)-\(title)"
    }
}

struct SettingsSearchEntry: Identifiable {
    let tab: SettingsTab
    let title: String
    let keywords: [String]
    let highlightID: String?
    /// Which segment of the Lock Screen tab owns this setting.
    ///
    /// The Lock Screen tab is split into General and Widgets, so opening a
    /// search result there has to pick a segment before it can scroll. Keeping
    /// that here rather than in a separate list means the one table you must
    /// edit to make a setting searchable is also the one that routes it -- a
    /// setting missing from here was never reachable from search to begin with.
    let lockScreenSection: LockScreenSettingsSection?

    init(
        tab: SettingsTab,
        title: String,
        keywords: [String],
        highlightID: String?,
        lockScreenSection: LockScreenSettingsSection? = nil
    ) {
        self.tab = tab
        self.title = title
        self.keywords = keywords
        self.highlightID = highlightID
        self.lockScreenSection = lockScreenSection
    }

    var id: String { "\(tab.rawValue)-\(title)" }
}

/// The two segments of the Lock Screen settings tab.
///
/// The tab holds fourteen sections, ten of which configure one widget each.
/// All of them at once is a long scroll where the global settings -- the ones
/// you came for when you are not adjusting a particular widget -- are buried
/// among the per-widget ones.
enum LockScreenSettingsSection: String, CaseIterable, Identifiable {
    case general
    case widgets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return String(localized: "General")
        case .widgets: return String(localized: "Widgets")
        }
    }
}

enum SettingsSearchIndex {
    static let entries: [SettingsSearchEntry] = [
        // General
        SettingsSearchEntry(tab: .general, title: "Enable Minimalistic UI", keywords: ["minimalistic", "ui mode", "general"], highlightID: SettingsTab.general.highlightID(for: "Enable Minimalistic UI")),
        SettingsSearchEntry(tab: .general, title: "Menubar icon", keywords: ["menu bar", "status bar", "icon"], highlightID: SettingsTab.general.highlightID(for: "Menubar icon")),
        SettingsSearchEntry(tab: .general, title: "Launch at login", keywords: ["autostart", "startup"], highlightID: SettingsTab.general.highlightID(for: "Launch at login")),
        SettingsSearchEntry(tab: .general, title: "Show on all displays", keywords: ["multi-display", "external monitor"], highlightID: SettingsTab.general.highlightID(for: "Show on all displays")),
        SettingsSearchEntry(tab: .general, title: "Show on a specific display", keywords: ["preferred screen", "display picker"], highlightID: SettingsTab.general.highlightID(for: "Show on a specific display")),
        SettingsSearchEntry(tab: .general, title: "Automatically switch displays", keywords: ["auto switch", "displays"], highlightID: SettingsTab.general.highlightID(for: "Automatically switch displays")),
        SettingsSearchEntry(tab: .general, title: "Hide Dynamic Island during screenshots & recordings", keywords: ["privacy", "screenshot", "recording"], highlightID: SettingsTab.general.highlightID(for: "Hide Dynamic Island during screenshots & recordings")),
        SettingsSearchEntry(tab: .general, title: "Enable Keep Awake", keywords: ["caffeinate", "keep awake", "prevent sleep", "insomnia", "no sleep"], highlightID: SettingsTab.general.highlightID(for: "Enable Keep Awake")),
        SettingsSearchEntry(tab: .general, title: "Show Keep Awake icon in the notch", keywords: ["caffeinate", "keep awake", "icon", "notch"], highlightID: SettingsTab.general.highlightID(for: "Show Keep Awake icon in the notch")),
        SettingsSearchEntry(tab: .general, title: "Default duration", keywords: ["caffeinate", "keep awake", "duration", "timeout"], highlightID: SettingsTab.general.highlightID(for: "Default duration")),
        SettingsSearchEntry(tab: .general, title: "Also keep the display awake", keywords: ["caffeinate", "keep awake", "display sleep", "screen"], highlightID: SettingsTab.general.highlightID(for: "Also keep the display awake")),
        SettingsSearchEntry(tab: .general, title: "Enable gestures", keywords: ["gestures", "trackpad"], highlightID: SettingsTab.general.highlightID(for: "Enable gestures")),
        SettingsSearchEntry(tab: .general, title: "Close gesture", keywords: ["pinch", "swipe"], highlightID: SettingsTab.general.highlightID(for: "Close gesture")),
        SettingsSearchEntry(tab: .general, title: "Reverse swipe gestures", keywords: ["reverse", "swipe", "media"], highlightID: SettingsTab.general.highlightID(for: "Reverse swipe gestures")),
        SettingsSearchEntry(tab: .general, title: "Reverse scroll gestures", keywords: ["reverse", "scroll", "open", "close"], highlightID: SettingsTab.general.highlightID(for: "Reverse scroll gestures")),
        SettingsSearchEntry(tab: .general, title: "Extend hover area", keywords: ["hover", "cursor"], highlightID: SettingsTab.general.highlightID(for: "Extend hover area")),
        SettingsSearchEntry(tab: .general, title: "Enable haptics", keywords: ["haptic", "feedback"], highlightID: SettingsTab.general.highlightID(for: "Enable haptics")),
        SettingsSearchEntry(tab: .general, title: "Open notch on hover", keywords: ["hover to open", "auto open"], highlightID: SettingsTab.general.highlightID(for: "Open notch on hover")),
        SettingsSearchEntry(tab: .general, title: "External display style", keywords: ["dynamic island", "pill", "external display", "non-notch", "floating", "capsule"], highlightID: SettingsTab.general.highlightID(for: "External display style")),
        SettingsSearchEntry(tab: .general, title: "Hide until hovered", keywords: ["hide", "hover", "external", "non-notch", "auto hide", "slide"], highlightID: SettingsTab.general.highlightID(for: "Hide until hovered")),
        SettingsSearchEntry(tab: .general, title: "Notch display height", keywords: ["display height", "menu bar size"], highlightID: SettingsTab.general.highlightID(for: "Notch display height")),

        // Live Activities
        SettingsSearchEntry(tab: .liveActivities, title: "Enable Screen Recording Detection", keywords: ["screen recording", "indicator"], highlightID: SettingsTab.liveActivities.highlightID(for: "Enable Screen Recording Detection")),
        SettingsSearchEntry(tab: .liveActivities, title: "Show Recording Indicator", keywords: ["recording indicator", "red dot"], highlightID: SettingsTab.liveActivities.highlightID(for: "Show Recording Indicator")),
        SettingsSearchEntry(tab: .liveActivities, title: "Recording Controls", keywords: ["screen recording", "stop button", "indicator"], highlightID: SettingsTab.liveActivities.highlightID(for: "Recording Controls")),
        SettingsSearchEntry(tab: .liveActivities, title: "Recording Hover Style", keywords: ["screen recording", "hover", "inline", "stop"], highlightID: SettingsTab.liveActivities.highlightID(for: "Recording Hover Style")),
        SettingsSearchEntry(tab: .liveActivities, title: "Enable Focus Detection", keywords: ["focus", "do not disturb", "dnd"], highlightID: SettingsTab.liveActivities.highlightID(for: "Enable Focus Detection")),
        SettingsSearchEntry(tab: .liveActivities, title: "Show Focus Indicator", keywords: ["focus icon", "moon"], highlightID: SettingsTab.liveActivities.highlightID(for: "Show Focus Indicator")),
        SettingsSearchEntry(tab: .liveActivities, title: "Show Focus Label", keywords: ["focus label", "text"], highlightID: SettingsTab.liveActivities.highlightID(for: "Show Focus Label")),
        SettingsSearchEntry(tab: .liveActivities, title: "Enable Camera Detection", keywords: ["camera", "privacy indicator"], highlightID: SettingsTab.liveActivities.highlightID(for: "Enable Camera Detection")),
        SettingsSearchEntry(tab: .liveActivities, title: "Enable Microphone Detection", keywords: ["microphone", "privacy"], highlightID: SettingsTab.liveActivities.highlightID(for: "Enable Microphone Detection")),
        SettingsSearchEntry(tab: .liveActivities, title: "Enable music live activity", keywords: ["music", "now playing"], highlightID: SettingsTab.liveActivities.highlightID(for: "Enable music live activity")),
        SettingsSearchEntry(tab: .liveActivities, title: "Enable reminder live activity", keywords: ["reminder", "live activity"], highlightID: SettingsTab.liveActivities.highlightID(for: "Enable reminder live activity")),

        // Battery (Charge)
        SettingsSearchEntry(tab: .battery, title: "Show battery indicator", keywords: ["battery hud", "charge"], highlightID: SettingsTab.battery.highlightID(for: "Show battery indicator")),
        SettingsSearchEntry(tab: .battery, title: "Show battery percentage", keywords: ["battery percent"], highlightID: SettingsTab.battery.highlightID(for: "Show battery percentage")),
        SettingsSearchEntry(tab: .battery, title: "Show power status notifications", keywords: ["notifications", "power"], highlightID: SettingsTab.battery.highlightID(for: "Show power status notifications")),
        SettingsSearchEntry(tab: .battery, title: "Show power status icons", keywords: ["power icons", "charging icon"], highlightID: SettingsTab.battery.highlightID(for: "Show power status icons")),
        SettingsSearchEntry(tab: .battery, title: "Play low battery alert sound", keywords: ["low battery", "alert", "sound"], highlightID: SettingsTab.battery.highlightID(for: "Play low battery alert sound")),
        SettingsSearchEntry(tab: .battery, title: "Charging HUD", keywords: ["battery", "charging", "temporary activity"], highlightID: SettingsTab.battery.highlightID(for: "Charging HUD")),
        SettingsSearchEntry(tab: .battery, title: "Low battery HUD", keywords: ["battery", "low", "temporary activity"], highlightID: SettingsTab.battery.highlightID(for: "Low battery HUD")),
        SettingsSearchEntry(tab: .battery, title: "Fully charged HUD", keywords: ["battery", "full", "temporary activity"], highlightID: SettingsTab.battery.highlightID(for: "Fully charged HUD")),
        SettingsSearchEntry(tab: .battery, title: "Charging duration", keywords: ["charging", "duration", "seconds"], highlightID: SettingsTab.battery.highlightID(for: "Charging duration")),
        SettingsSearchEntry(tab: .battery, title: "Low battery duration", keywords: ["low battery", "duration", "seconds"], highlightID: SettingsTab.battery.highlightID(for: "Low battery duration")),
        SettingsSearchEntry(tab: .battery, title: "Full battery duration", keywords: ["full battery", "duration", "seconds"], highlightID: SettingsTab.battery.highlightID(for: "Full battery duration")),
        SettingsSearchEntry(tab: .battery, title: "Test charging HUD", keywords: ["battery", "test", "charging", "preview"], highlightID: nil),
        SettingsSearchEntry(tab: .battery, title: "Test low battery HUD", keywords: ["battery", "test", "low", "preview"], highlightID: nil),
        SettingsSearchEntry(tab: .battery, title: "Test full battery HUD", keywords: ["battery", "test", "full", "preview"], highlightID: nil),
        SettingsSearchEntry(tab: .battery, title: "Low battery style", keywords: ["battery", "style", "compact", "standard"], highlightID: SettingsTab.battery.highlightID(for: "Low battery style")),
        SettingsSearchEntry(tab: .battery, title: "Low battery threshold", keywords: ["battery", "threshold", "percent"], highlightID: SettingsTab.battery.highlightID(for: "Low battery threshold")),
        SettingsSearchEntry(tab: .battery, title: "Full battery style", keywords: ["battery", "style", "compact", "standard"], highlightID: SettingsTab.battery.highlightID(for: "Full battery style")),
        SettingsSearchEntry(tab: .battery, title: "Full charge threshold", keywords: ["battery", "threshold", "full"], highlightID: SettingsTab.battery.highlightID(for: "Full charge threshold")),
        SettingsSearchEntry(tab: .devices, title: "Enable per-app volume", keywords: ["per app volume", "app volume", "mixer", "audio", "mute app"], highlightID: SettingsTab.devices.highlightID(for: "Enable per-app volume")),
        SettingsSearchEntry(tab: .devices, title: "Show app volume icon in the notch", keywords: ["per app volume", "icon", "notch", "mixer"], highlightID: SettingsTab.devices.highlightID(for: "Show app volume icon in the notch")),
        SettingsSearchEntry(tab: .devices, title: "Reset all app volumes", keywords: ["per app volume", "reset", "mixer"], highlightID: SettingsTab.devices.highlightID(for: "Reset all app volumes")),

        // HUDs
        SettingsSearchEntry(tab: .devices, title: "Show Bluetooth device connections", keywords: ["bluetooth", "hud"], highlightID: SettingsTab.devices.highlightID(for: "Show Bluetooth device connections")),
        SettingsSearchEntry(tab: .devices, title: "Use circular battery indicator", keywords: ["battery", "circular"], highlightID: SettingsTab.devices.highlightID(for: "Use circular battery indicator")),
        SettingsSearchEntry(tab: .devices, title: "Show battery percentage text in HUD", keywords: ["battery text"], highlightID: SettingsTab.devices.highlightID(for: "Show battery percentage text in HUD")),
        SettingsSearchEntry(tab: .devices, title: "Scroll device name in HUD", keywords: ["marquee", "device name"], highlightID: SettingsTab.devices.highlightID(for: "Scroll device name in HUD")),
        SettingsSearchEntry(tab: .devices, title: "Use 3D Bluetooth HUD icon", keywords: ["bluetooth", "3d", "animation", "mov"], highlightID: SettingsTab.devices.highlightID(for: "Use 3D Bluetooth HUD icon")),
        SettingsSearchEntry(tab: .devices, title: "Color-coded battery display", keywords: ["color", "battery"], highlightID: SettingsTab.devices.highlightID(for: "Color-coded battery display")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Color-coded volume display", keywords: ["volume", "color"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Color-coded volume display")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Smooth color transitions", keywords: ["gradient", "smooth"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Smooth color transitions")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Show percentages beside progress bars", keywords: ["percentages", "progress"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Show percentages beside progress bars")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "HUD style", keywords: ["inline", "compact"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "HUD style")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Progressbar style", keywords: ["progress", "style"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Progressbar style")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Enable glowing effect", keywords: ["glow", "indicator"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Enable glowing effect")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Use accent color", keywords: ["accent", "color"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Use accent color")),

        // Custom OSD
        SettingsSearchEntry(tab: .hudAndOSD, title: "Enable Custom OSD", keywords: ["osd", "on-screen display", "custom osd"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Enable Custom OSD")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Volume OSD", keywords: ["volume", "osd"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Volume OSD")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Brightness OSD", keywords: ["brightness", "osd"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Brightness OSD")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Keyboard Backlight OSD", keywords: ["keyboard", "backlight", "osd"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Keyboard Backlight OSD")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Material", keywords: ["material", "frosted", "liquid", "glass", "solid", "osd"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Material")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Icon & Progress Color", keywords: ["color", "icon", "white", "black", "gray", "osd"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Icon & Progress Color")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Volume step", keywords: ["volume", "step", "percent"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Volume step")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Volume fine step", keywords: ["volume", "fine", "step", "percent"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Volume fine step")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Brightness step", keywords: ["brightness", "step", "percent"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Brightness step")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Brightness fine step", keywords: ["brightness", "fine", "step", "percent"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Brightness fine step")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Third-party DDC app integration", keywords: ["ddc", "third party", "external", "display", "betterdisplay", "lunar"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Third-party DDC app integration")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Third-party DDC provider", keywords: ["provider", "betterdisplay", "lunar", "integration", "refresh detection"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Third-party DDC provider")),
        SettingsSearchEntry(tab: .hudAndOSD, title: "Enable external volume control listener", keywords: ["external volume", "ddc volume", "betterdisplay volume", "lunar volume", "disable native volume"], highlightID: SettingsTab.hudAndOSD.highlightID(for: "Enable external volume control listener")),

        // Media
        SettingsSearchEntry(tab: .media, title: "Music Source", keywords: ["media source", "controller"], highlightID: SettingsTab.media.highlightID(for: "Music Source")),
        SettingsSearchEntry(tab: .media, title: "Skip buttons", keywords: ["skip", "controls", "±10"], highlightID: SettingsTab.media.highlightID(for: "Skip buttons")),
        SettingsSearchEntry(tab: .media, title: "Sneak Peek Style", keywords: ["sneak peek", "preview"], highlightID: SettingsTab.media.highlightID(for: "Sneak Peek Style")),
        SettingsSearchEntry(tab: .media, title: "Keep lyrics under the closed notch", keywords: ["lyrics", "pin", "pinned", "closed notch", "always show"], highlightID: SettingsTab.media.highlightID(for: "Keep lyrics under the closed notch")),
        SettingsSearchEntry(tab: .media, title: "Show lyrics", keywords: ["lyrics", "song text", "side panel", "calendar", "inline"], highlightID: SettingsTab.media.highlightID(for: "Show lyrics")),
        // Targets the lyrics toggle rather than the Highlight picker: the picker
        // only exists while lyrics are on, so a search result pointing at it
        // scrolls to nothing for anyone who has not turned them on yet -- which
        // is everyone, by default.
        SettingsSearchEntry(tab: .media, title: "Lyric highlight", keywords: ["lyrics", "highlight", "sweep", "gradient", "solid", "karaoke", "animation"], highlightID: SettingsTab.media.highlightID(for: "Show lyrics")),
        SettingsSearchEntry(tab: .media, title: "Side lyrics width", keywords: ["lyrics", "width", "panel"], highlightID: SettingsTab.media.highlightID(for: "Side lyrics width")),
        SettingsSearchEntry(tab: .media, title: "Side lyrics horizontal offset", keywords: ["lyrics", "offset", "panel"], highlightID: SettingsTab.media.highlightID(for: "Side lyrics horizontal offset")),
        SettingsSearchEntry(tab: .media, title: "Show live canvas in Dynamic Island", keywords: ["canvas", "live canvas", "album art", "dynamic island", "spotify canvas"], highlightID: SettingsTab.media.highlightID(for: "Show live canvas in Dynamic Island")),
        SettingsSearchEntry(tab: .media, title: "Auto-hide inactive notch media player", keywords: ["auto hide", "inactive", "placeholder", "notch media"], highlightID: SettingsTab.media.highlightID(for: "Auto-hide inactive notch media player")),
        SettingsSearchEntry(tab: .media, title: "Show Change Media Output control", keywords: ["airplay", "route picker", "media output"], highlightID: SettingsTab.media.highlightID(for: "Show Change Media Output control")),
        SettingsSearchEntry(tab: .media, title: "Enable album art parallax", keywords: ["parallax", "lock screen", "album art"], highlightID: SettingsTab.media.highlightID(for: "Enable album art parallax")),
        SettingsSearchEntry(tab: .media, title: "Enable album art parallax effect", keywords: ["parallax", "parallax effect", "album art"], highlightID: SettingsTab.media.highlightID(for: "Enable album art parallax effect")),

        // Calendar
        SettingsSearchEntry(tab: .calendar, title: "Show calendar", keywords: ["calendar", "events"], highlightID: SettingsTab.calendar.highlightID(for: "Show calendar")),
        SettingsSearchEntry(tab: .calendar, title: "Enable reminder live activity", keywords: ["reminder", "live activity"], highlightID: SettingsTab.calendar.highlightID(for: "Enable reminder live activity")),
        SettingsSearchEntry(tab: .calendar, title: "Countdown style", keywords: ["reminder countdown"], highlightID: SettingsTab.calendar.highlightID(for: "Countdown style")),
        SettingsSearchEntry(tab: .calendar, title: "Show lock screen reminder", keywords: ["lock screen", "reminder widget"], highlightID: SettingsTab.calendar.highlightID(for: "Show lock screen reminder")),
        SettingsSearchEntry(tab: .calendar, title: "Show next calendar event", keywords: ["calendar widget", "lock screen", "next event"], highlightID: SettingsTab.calendar.highlightID(for: "Show next calendar event")),
        SettingsSearchEntry(tab: .calendar, title: "Show events within the next", keywords: ["calendar widget", "lookahead"], highlightID: SettingsTab.calendar.highlightID(for: "Show events within the next")),
        SettingsSearchEntry(tab: .calendar, title: "Show events from all calendars", keywords: ["calendar widget", "selection"], highlightID: SettingsTab.calendar.highlightID(for: "Show events from all calendars")),
        SettingsSearchEntry(tab: .calendar, title: "Show countdown", keywords: ["calendar widget", "countdown"], highlightID: SettingsTab.calendar.highlightID(for: "Show countdown")),
        SettingsSearchEntry(tab: .calendar, title: "Show event for entire duration", keywords: ["calendar widget", "duration"], highlightID: SettingsTab.calendar.highlightID(for: "Show event for entire duration")),
        SettingsSearchEntry(tab: .calendar, title: "Hide active event and show next upcoming event", keywords: ["calendar widget", "after start"], highlightID: SettingsTab.calendar.highlightID(for: "Hide active event and show next upcoming event")),
        SettingsSearchEntry(tab: .calendar, title: "Show time remaining", keywords: ["calendar widget", "remaining"], highlightID: SettingsTab.calendar.highlightID(for: "Show time remaining")),
        SettingsSearchEntry(tab: .calendar, title: "Show start time after event begins", keywords: ["calendar widget", "start time"], highlightID: SettingsTab.calendar.highlightID(for: "Show start time after event begins")),
        SettingsSearchEntry(tab: .calendar, title: "Chip color", keywords: ["reminder chip", "color"], highlightID: SettingsTab.calendar.highlightID(for: "Chip color")),
        SettingsSearchEntry(tab: .calendar, title: "Hide all-day events", keywords: ["calendar", "all-day"], highlightID: SettingsTab.calendar.highlightID(for: "Hide all-day events")),
        SettingsSearchEntry(tab: .calendar, title: "Hide completed reminders", keywords: ["reminder", "completed"], highlightID: SettingsTab.calendar.highlightID(for: "Hide completed reminders")),
        SettingsSearchEntry(tab: .calendar, title: "Show full event titles", keywords: ["calendar", "titles"], highlightID: SettingsTab.calendar.highlightID(for: "Show full event titles")),
        SettingsSearchEntry(tab: .calendar, title: "Auto-scroll to next event", keywords: ["calendar", "scroll"], highlightID: SettingsTab.calendar.highlightID(for: "Auto-scroll to next event")),

        // Shelf
        SettingsSearchEntry(tab: .shelf, title: "Enable shelf", keywords: ["shelf", "dock"], highlightID: SettingsTab.shelf.highlightID(for: "Enable shelf")),
        SettingsSearchEntry(tab: .shelf, title: "Open shelf tab by default if items added", keywords: ["auto open", "shelf tab"], highlightID: SettingsTab.shelf.highlightID(for: "Open shelf tab by default if items added")),
        SettingsSearchEntry(tab: .shelf, title: "Expanded drag detection area", keywords: ["shelf", "drag"], highlightID: SettingsTab.shelf.highlightID(for: "Expanded drag detection area")),
        SettingsSearchEntry(tab: .shelf, title: "Copy items on drag", keywords: ["shelf", "drag", "copy"], highlightID: SettingsTab.shelf.highlightID(for: "Copy items on drag")),
        SettingsSearchEntry(tab: .shelf, title: "Remove from shelf after dragging", keywords: ["shelf", "drag", "remove"], highlightID: SettingsTab.shelf.highlightID(for: "Remove from shelf after dragging")),
        SettingsSearchEntry(tab: .shelf, title: "Quick Share Service", keywords: ["shelf", "share", "airdrop", "localsend"], highlightID: SettingsTab.shelf.highlightID(for: "Quick Share Service")),
        SettingsSearchEntry(tab: .shelf, title: "LocalSend Device Picker Style", keywords: ["localsend", "glass", "picker", "material"], highlightID: SettingsTab.shelf.highlightID(for: "Device Picker Style")),

        // Appearance
        SettingsSearchEntry(tab: .appearance, title: "Main screen style", keywords: ["dynamic island", "pill", "non-notch", "display style", "notch style"], highlightID: SettingsTab.appearance.highlightID(for: "Main screen style")),
        SettingsSearchEntry(tab: .appearance, title: "Settings icon in notch", keywords: ["settings button", "toolbar"], highlightID: SettingsTab.appearance.highlightID(for: "Settings icon in notch")),
        SettingsSearchEntry(tab: .appearance, title: "Enable window shadow", keywords: ["shadow", "appearance"], highlightID: SettingsTab.appearance.highlightID(for: "Enable window shadow")),
        SettingsSearchEntry(tab: .appearance, title: "Corner radius scaling", keywords: ["corner radius", "shape"], highlightID: SettingsTab.appearance.highlightID(for: "Corner radius scaling")),
        SettingsSearchEntry(tab: .appearance, title: "Use simpler close animation", keywords: ["close animation", "notch"], highlightID: SettingsTab.appearance.highlightID(for: "Use simpler close animation")),
        SettingsSearchEntry(tab: .appearance, title: "Notch Width", keywords: ["expanded notch", "width", "resize"], highlightID: SettingsTab.appearance.highlightID(for: "Expanded notch width")),
        SettingsSearchEntry(tab: .appearance, title: "Enable colored spectrograms", keywords: ["spectrogram", "audio"], highlightID: SettingsTab.appearance.highlightID(for: "Enable colored spectrograms")),
        SettingsSearchEntry(tab: .appearance, title: "Enable blur effect behind album art", keywords: ["blur", "album art"], highlightID: SettingsTab.appearance.highlightID(for: "Enable blur effect behind album art")),
        SettingsSearchEntry(tab: .appearance, title: "Slider color", keywords: ["slider", "accent"], highlightID: SettingsTab.appearance.highlightID(for: "Slider color")),
        SettingsSearchEntry(tab: .appearance, title: "Enable Dynamic mirror", keywords: ["mirror", "reflection"], highlightID: SettingsTab.appearance.highlightID(for: "Enable Dynamic mirror")),
        SettingsSearchEntry(tab: .appearance, title: "Mirror shape", keywords: ["mirror shape", "circle", "rectangle"], highlightID: SettingsTab.appearance.highlightID(for: "Mirror shape")),
        SettingsSearchEntry(tab: .appearance, title: "Idle Animation", keywords: ["face animation", "idle", "cool face"], highlightID: SettingsTab.appearance.highlightID(for: "Idle Animation")),
        SettingsSearchEntry(tab: .appearance, title: "App icon", keywords: ["app icon", "custom icon"], highlightID: SettingsTab.appearance.highlightID(for: "App icon")),

        // Lock Screen
        SettingsSearchEntry(tab: .lockScreen, title: "Preview lock screen widgets", keywords: ["preview", "lock screen", "widgets"], highlightID: SettingsTab.lockScreen.highlightID(for: "Preview lock screen widgets"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Widget appearance", keywords: ["appearance", "theme", "dark", "light", "contrast", "wallpaper"], highlightID: SettingsTab.lockScreen.highlightID(for: "Widget appearance"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Enable lock screen live activity", keywords: ["lock screen", "live activity"], highlightID: SettingsTab.lockScreen.highlightID(for: "Enable lock screen live activity"), lockScreenSection: .general),
        SettingsSearchEntry(tab: .lockScreen, title: "Live activity icon", keywords: ["lock", "fingerprint", "touch id", "unlock", "biometric", "icon style"], highlightID: SettingsTab.lockScreen.highlightID(for: "Live activity icon"), lockScreenSection: .general),
        SettingsSearchEntry(tab: .lockScreen, title: "Play lock/unlock sounds", keywords: ["chime", "sound"], highlightID: SettingsTab.lockScreen.highlightID(for: "Play lock/unlock sounds"), lockScreenSection: .general),
        SettingsSearchEntry(tab: .lockScreen, title: "Material", keywords: ["glass", "frosted", "liquid"], highlightID: SettingsTab.lockScreen.highlightID(for: "Material"), lockScreenSection: .general),
        SettingsSearchEntry(tab: .lockScreen, title: "Show lock screen media panel", keywords: ["media panel", "lock screen media"], highlightID: SettingsTab.lockScreen.highlightID(for: "Show lock screen media panel"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Show media app icon", keywords: ["app icon", "media"], highlightID: SettingsTab.lockScreen.highlightID(for: "Show media app icon"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Show panel border", keywords: ["panel border"], highlightID: SettingsTab.lockScreen.highlightID(for: "Show panel border"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Always show volume control", keywords: ["volume", "slider", "lock screen", "media output", "accessibility"], highlightID: SettingsTab.lockScreen.highlightID(for: "Always show volume control"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Enable media panel blur", keywords: ["blur", "media panel"], highlightID: SettingsTab.lockScreen.highlightID(for: "Enable media panel blur"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Show lock screen timer", keywords: ["timer widget", "lock screen timer"], highlightID: SettingsTab.lockScreen.highlightID(for: "Show lock screen timer"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Timer surface", keywords: ["timer glass", "classic", "blur"], highlightID: SettingsTab.lockScreen.highlightID(for: "Timer surface"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Timer glass material", keywords: ["frosted", "liquid", "timer material"], highlightID: SettingsTab.lockScreen.highlightID(for: "Timer glass material"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Timer liquid mode", keywords: ["timer", "standard", "custom"], highlightID: SettingsTab.lockScreen.highlightID(for: "Timer liquid mode"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Timer widget variant", keywords: ["timer variant", "liquid"], highlightID: SettingsTab.lockScreen.highlightID(for: "Timer widget variant"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Show lock screen weather", keywords: ["weather widget"], highlightID: SettingsTab.lockScreen.highlightID(for: "Show lock screen weather"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Widget layout", keywords: ["inline", "circular", "widget layout", "weather layout", "status widget"], highlightID: SettingsTab.lockScreen.highlightID(for: "Widget layout"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Weather data provider", keywords: ["wttr", "open meteo"], highlightID: SettingsTab.lockScreen.highlightID(for: "Weather data provider"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Temperature unit", keywords: ["celsius", "fahrenheit"], highlightID: SettingsTab.lockScreen.highlightID(for: "Temperature unit"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Show location label", keywords: ["location", "weather"], highlightID: SettingsTab.lockScreen.highlightID(for: "Show location label"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Show charging status", keywords: ["charging", "weather"], highlightID: SettingsTab.lockScreen.highlightID(for: "Show charging status"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Show charging percentage", keywords: ["charging percentage"], highlightID: SettingsTab.lockScreen.highlightID(for: "Show charging percentage"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Show battery indicator", keywords: ["battery gauge", "weather"], highlightID: SettingsTab.lockScreen.highlightID(for: "Show battery indicator"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Use MacBook icon when on battery", keywords: ["laptop icon", "battery"], highlightID: SettingsTab.lockScreen.highlightID(for: "Use MacBook icon when on battery"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Show Bluetooth battery", keywords: ["bluetooth", "gauge"], highlightID: SettingsTab.lockScreen.highlightID(for: "Show Bluetooth battery"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Show AQI widget", keywords: ["air quality", "aqi"], highlightID: SettingsTab.lockScreen.highlightID(for: "Show AQI widget"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Air quality scale", keywords: ["aqi", "scale"], highlightID: SettingsTab.lockScreen.highlightID(for: "Air quality scale"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Use colored gauges", keywords: ["gauge tint", "monochrome"], highlightID: SettingsTab.lockScreen.highlightID(for: "Use colored gauges"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Show lock screen reminder", keywords: ["lock screen", "reminder widget"], highlightID: SettingsTab.lockScreen.highlightID(for: "Show lock screen reminder"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Chip color", keywords: ["reminder chip", "color"], highlightID: SettingsTab.lockScreen.highlightID(for: "Chip color"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Reminder alignment", keywords: ["reminder", "alignment", "position"], highlightID: SettingsTab.lockScreen.highlightID(for: "Reminder alignment"), lockScreenSection: .widgets),
        SettingsSearchEntry(tab: .lockScreen, title: "Reminder vertical offset", keywords: ["reminder", "offset", "position"], highlightID: SettingsTab.lockScreen.highlightID(for: "Reminder vertical offset"), lockScreenSection: .widgets),

        // Extensions
        SettingsSearchEntry(tab: .extensions, title: "Enable third-party extensions", keywords: ["extensions", "authorization", "third party"], highlightID: SettingsTab.extensions.highlightID(for: "Enable third-party extensions")),
        SettingsSearchEntry(tab: .extensions, title: "Allow extension live activities", keywords: ["extensions", "live activities", "permissions"], highlightID: SettingsTab.extensions.highlightID(for: "Allow extension live activities")),
        SettingsSearchEntry(tab: .extensions, title: "Allow extension lock screen widgets", keywords: ["extensions", "lock screen", "widgets"], highlightID: SettingsTab.extensions.highlightID(for: "Allow extension lock screen widgets")),
        SettingsSearchEntry(tab: .extensions, title: "Enable extension diagnostics logging", keywords: ["extensions", "diagnostics", "logging"], highlightID: SettingsTab.extensions.highlightID(for: "Enable extension diagnostics logging")),
        SettingsSearchEntry(tab: .extensions, title: "Manage app permissions", keywords: ["extensions", "permissions", "apps"], highlightID: SettingsTab.extensions.highlightID(for: "App permissions list")),
        SettingsSearchEntry(tab: .extensions, title: "Browse the Marketplace", keywords: ["marketplace", "extensions", "install", "download", "store", "getatoll"], highlightID: SettingsTab.extensions.highlightID(for: "Browse the Marketplace")),

        // Shortcuts
        SettingsSearchEntry(tab: .shortcuts, title: "Enable global keyboard shortcuts", keywords: ["keyboard", "shortcut"], highlightID: SettingsTab.shortcuts.highlightID(for: "Enable global keyboard shortcuts")),

        // Timer
        SettingsSearchEntry(tab: .timer, title: "Enable timer feature", keywords: ["timer", "enable"], highlightID: SettingsTab.timer.highlightID(for: "Enable timer feature")),
        SettingsSearchEntry(tab: .timer, title: "Mirror macOS Clock timers", keywords: ["system timer", "clock app"], highlightID: SettingsTab.timer.highlightID(for: "Mirror macOS Clock timers")),
        SettingsSearchEntry(tab: .timer, title: "Show lock screen timer widget", keywords: ["lock screen", "timer widget"], highlightID: SettingsTab.timer.highlightID(for: "Show lock screen timer widget")),
        SettingsSearchEntry(tab: .timer, title: "Timer surface", keywords: ["timer glass", "classic", "blur"], highlightID: SettingsTab.timer.highlightID(for: "Timer surface")),
        SettingsSearchEntry(tab: .timer, title: "Timer glass material", keywords: ["frosted", "liquid", "timer material"], highlightID: SettingsTab.timer.highlightID(for: "Timer glass material")),
        SettingsSearchEntry(tab: .timer, title: "Timer liquid mode", keywords: ["timer", "standard", "custom"], highlightID: SettingsTab.timer.highlightID(for: "Timer liquid mode")),
        SettingsSearchEntry(tab: .timer, title: "Timer widget variant", keywords: ["timer variant", "liquid"], highlightID: SettingsTab.timer.highlightID(for: "Timer widget variant")),
        SettingsSearchEntry(tab: .timer, title: "Timer tint", keywords: ["timer colour", "preset"], highlightID: SettingsTab.timer.highlightID(for: "Timer tint")),
        SettingsSearchEntry(tab: .timer, title: "Solid colour", keywords: ["timer colour", "custom"], highlightID: SettingsTab.timer.highlightID(for: "Solid colour")),
        SettingsSearchEntry(tab: .timer, title: "Progress style", keywords: ["progress", "bar", "ring"], highlightID: SettingsTab.timer.highlightID(for: "Progress style")),
        SettingsSearchEntry(tab: .timer, title: "Accent colour", keywords: ["accent", "timer"], highlightID: SettingsTab.timer.highlightID(for: "Accent colour")),

        // Stats
        SettingsSearchEntry(tab: .stats, title: "Enable system stats monitoring", keywords: ["stats", "monitoring"], highlightID: SettingsTab.stats.highlightID(for: "Enable system stats monitoring")),
        SettingsSearchEntry(tab: .stats, title: "Enable LLM Usage Monitor", keywords: ["llm", "usage", "ai", "monitor"], highlightID: SettingsTab.stats.highlightID(for: "Enable LLM Usage Monitor")),
        SettingsSearchEntry(tab: .stats, title: "Claude Provider", keywords: ["llm", "claude", "provider", "toggle"], highlightID: SettingsTab.stats.highlightID(for: "Claude Provider")),
        SettingsSearchEntry(tab: .stats, title: "Codex Provider", keywords: ["llm", "codex", "provider", "toggle"], highlightID: SettingsTab.stats.highlightID(for: "Codex Provider")),
        SettingsSearchEntry(tab: .stats, title: "Cursor Provider", keywords: ["llm", "cursor", "provider", "toggle"], highlightID: SettingsTab.stats.highlightID(for: "Cursor Provider")),
        SettingsSearchEntry(tab: .stats, title: "Antigravity Provider", keywords: ["llm", "antigravity", "provider", "toggle"], highlightID: SettingsTab.stats.highlightID(for: "Antigravity Provider")),
        SettingsSearchEntry(tab: .stats, title: "New API Provider", keywords: ["llm", "new api", "newapi", "provider", "toggle"], highlightID: SettingsTab.stats.highlightID(for: "New API Provider")),
        SettingsSearchEntry(tab: .stats, title: "New API Accounts", keywords: ["llm", "new api", "newapi", "accounts", "key", "token"], highlightID: SettingsTab.stats.highlightID(for: "New API Accounts")),
        SettingsSearchEntry(tab: .stats, title: "Stop monitoring after closing the notch", keywords: ["stats", "auto stop"], highlightID: SettingsTab.stats.highlightID(for: "Stop monitoring after closing the notch")),
        SettingsSearchEntry(tab: .stats, title: "CPU Usage", keywords: ["cpu", "graph"], highlightID: SettingsTab.stats.highlightID(for: "CPU Usage")),
        SettingsSearchEntry(tab: .stats, title: "Temperature unit", keywords: ["cpu", "temperature", "celsius", "fahrenheit"], highlightID: SettingsTab.stats.highlightID(for: "Temperature unit")),
        SettingsSearchEntry(tab: .stats, title: "Memory Usage", keywords: ["memory", "ram"], highlightID: SettingsTab.stats.highlightID(for: "Memory Usage")),
        SettingsSearchEntry(tab: .stats, title: "GPU Usage", keywords: ["gpu", "graphics"], highlightID: SettingsTab.stats.highlightID(for: "GPU Usage")),
        SettingsSearchEntry(tab: .stats, title: "Network Activity", keywords: ["network", "graph"], highlightID: SettingsTab.stats.highlightID(for: "Network Activity")),
        SettingsSearchEntry(tab: .stats, title: "Disk I/O", keywords: ["disk", "io"], highlightID: SettingsTab.stats.highlightID(for: "Disk I/O")),

        // Clipboard
        SettingsSearchEntry(tab: .clipboard, title: "Enable Clipboard Manager", keywords: ["clipboard", "manager"], highlightID: SettingsTab.clipboard.highlightID(for: "Enable Clipboard Manager")),
        SettingsSearchEntry(tab: .clipboard, title: "Show Clipboard Icon", keywords: ["icon", "clipboard"], highlightID: SettingsTab.clipboard.highlightID(for: "Show Clipboard Icon")),
        SettingsSearchEntry(tab: .clipboard, title: "Save History Across Restarts", keywords: ["clipboard", "history", "save", "persist", "privacy", "disk", "disable"], highlightID: SettingsTab.clipboard.highlightID(for: "Enable Clipboard Manager")),
        SettingsSearchEntry(tab: .clipboard, title: "Display Mode", keywords: ["list", "grid", "clipboard"], highlightID: SettingsTab.clipboard.highlightID(for: "Display Mode")),
        SettingsSearchEntry(tab: .clipboard, title: "History Size", keywords: ["history", "clipboard"], highlightID: SettingsTab.clipboard.highlightID(for: "History Size")),

        // Screen Assistant
        SettingsSearchEntry(tab: .screenAssistant, title: "Enable Screen Assistant", keywords: ["screen assistant", "ai"], highlightID: SettingsTab.screenAssistant.highlightID(for: "Enable Screen Assistant")),
        SettingsSearchEntry(tab: .screenAssistant, title: "Display Mode", keywords: ["screen assistant", "mode"], highlightID: SettingsTab.screenAssistant.highlightID(for: "Display Mode")),

        // Color Picker
        SettingsSearchEntry(tab: .colorPicker, title: "Enable Color Picker", keywords: ["color picker", "eyedropper"], highlightID: SettingsTab.colorPicker.highlightID(for: "Enable Color Picker")),
        SettingsSearchEntry(tab: .colorPicker, title: "Show Color Picker Icon", keywords: ["color icon", "toolbar"], highlightID: SettingsTab.colorPicker.highlightID(for: "Show Color Picker Icon")),
        SettingsSearchEntry(tab: .colorPicker, title: "Display Mode", keywords: ["color", "list"], highlightID: SettingsTab.colorPicker.highlightID(for: "Display Mode")),
        SettingsSearchEntry(tab: .colorPicker, title: "History Size", keywords: ["color history"], highlightID: SettingsTab.colorPicker.highlightID(for: "History Size")),
        SettingsSearchEntry(tab: .colorPicker, title: "Show All Color Formats", keywords: ["hex", "hsl", "color formats"], highlightID: SettingsTab.colorPicker.highlightID(for: "Show All Color Formats")),

        // Terminal
        SettingsSearchEntry(tab: .terminal, title: "Enable terminal", keywords: ["terminal", "guake", "shell"], highlightID: SettingsTab.terminal.highlightID(for: "Enable terminal")),
        SettingsSearchEntry(tab: .terminal, title: "Shell path", keywords: ["shell", "zsh", "bash", "terminal"], highlightID: SettingsTab.terminal.highlightID(for: "Shell path")),
        SettingsSearchEntry(tab: .terminal, title: "Font size", keywords: ["terminal", "font", "text size"], highlightID: SettingsTab.terminal.highlightID(for: "Font size")),
        SettingsSearchEntry(tab: .terminal, title: "Terminal opacity", keywords: ["terminal", "opacity", "transparency", "blur", "background"], highlightID: SettingsTab.terminal.highlightID(for: "Terminal opacity")),
        SettingsSearchEntry(tab: .terminal, title: "Maximum height", keywords: ["terminal", "height", "size"], highlightID: SettingsTab.terminal.highlightID(for: "Maximum height")),
        SettingsSearchEntry(tab: .terminal, title: "Background color", keywords: ["terminal", "background", "color", "theme"], highlightID: SettingsTab.terminal.highlightID(for: "Background color")),
        SettingsSearchEntry(tab: .terminal, title: "Foreground color", keywords: ["terminal", "foreground", "text color", "theme"], highlightID: SettingsTab.terminal.highlightID(for: "Foreground color")),
        SettingsSearchEntry(tab: .terminal, title: "Cursor color", keywords: ["terminal", "cursor", "caret", "color"], highlightID: SettingsTab.terminal.highlightID(for: "Cursor color")),
        SettingsSearchEntry(tab: .terminal, title: "Bold as bright", keywords: ["terminal", "bold", "bright", "colors"], highlightID: SettingsTab.terminal.highlightID(for: "Bold as bright")),
        SettingsSearchEntry(tab: .terminal, title: "Cursor style", keywords: ["terminal", "cursor", "block", "underline", "bar", "blink"], highlightID: SettingsTab.terminal.highlightID(for: "Cursor style")),
        SettingsSearchEntry(tab: .terminal, title: "Scrollback lines", keywords: ["terminal", "scrollback", "buffer", "history"], highlightID: SettingsTab.terminal.highlightID(for: "Scrollback lines")),
        SettingsSearchEntry(tab: .terminal, title: "Option as Meta", keywords: ["terminal", "option", "meta", "alt", "key"], highlightID: SettingsTab.terminal.highlightID(for: "Option as Meta")),
        SettingsSearchEntry(tab: .terminal, title: "Mouse reporting", keywords: ["terminal", "mouse", "reporting", "vim", "tmux"], highlightID: SettingsTab.terminal.highlightID(for: "Mouse reporting")),
    ]

    /// Which segment of the Lock Screen tab a search result lives on, or nil
    /// when the id is not a Lock Screen setting.
    static func lockScreenSection(forHighlightID id: String) -> LockScreenSettingsSection? {
        entries.first { $0.tab == .lockScreen && $0.highlightID == id }?.lockScreenSection
    }
}

/// Drives "jump to this setting" from the search field.
///
/// `tab`, `pendingScrollRequest` and `focus(on:)` were `fileprivate` when
/// SettingsView lived in this file. SettingsView is its only caller and still
/// the only one that should be, but it is a separate file now, so they are
/// internal — the one visibility widening the split cost.
final class SettingsHighlightCoordinator: ObservableObject {
    struct ScrollRequest: Identifiable, Equatable {
        let id: String
        let tab: SettingsTab
    }

    @Published var pendingScrollRequest: ScrollRequest?
    @Published private(set) var activeHighlightID: String?

    private var clearWorkItem: DispatchWorkItem?

    func focus(on entry: SettingsSearchEntry) {
        guard let highlightID = entry.highlightID else { return }
        pendingScrollRequest = ScrollRequest(id: highlightID, tab: entry.tab)
        activateHighlight(id: highlightID)
    }

    func consumeScrollRequest(_ request: ScrollRequest) {
        guard pendingScrollRequest?.id == request.id else { return }
        pendingScrollRequest = nil
    }

    private func activateHighlight(id: String) {
        activeHighlightID = id
        clearWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard self?.activeHighlightID == id else { return }
            self?.activeHighlightID = nil
        }

        clearWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }
}

private struct SettingsHighlightModifier: ViewModifier {
    let id: String
    @EnvironmentObject private var highlightCoordinator: SettingsHighlightCoordinator
    @State private var animatePulse = false

    private var isActive: Bool {
        highlightCoordinator.activeHighlightID == id
    }

    func body(content: Content) -> some View {
        content
            .id(id)
            .background(highlightBackground)
            .onChange(of: isActive) { _, active in
                animatePulse = active
            }
            .onAppear {
                if isActive {
                    animatePulse = true
                }
            }
    }

    private var highlightBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(
                Color.accentColor.opacity(isActive ? (animatePulse ? 0.95 : 0.4) : 0),
                lineWidth: 2
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(isActive ? 0.08 : 0))
            )
            .padding(-4)
            .shadow(color: Color.accentColor.opacity(isActive ? 0.25 : 0), radius: animatePulse ? 8 : 2)
            .animation(
                isActive ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                value: animatePulse
            )
    }
}

extension View {
    func settingsHighlight(id: String) -> some View {
        modifier(SettingsHighlightModifier(id: id))
    }

    @ViewBuilder
    func settingsHighlightIfPresent(_ id: String?) -> some View {
        if let id {
            settingsHighlight(id: id)
        } else {
            self
        }
    }
}

struct SettingsForm<Content: View>: View {
    let tab: SettingsTab
    @ViewBuilder var content: () -> Content

    @EnvironmentObject private var highlightCoordinator: SettingsHighlightCoordinator

    var body: some View {
        ScrollViewReader { proxy in
            content()
                .onReceive(highlightCoordinator.$pendingScrollRequest.compactMap { request -> SettingsHighlightCoordinator.ScrollRequest? in
                    guard let request, request.tab == tab else { return nil }
                    return request
                }) { request in
                    withAnimation(.easeInOut(duration: 0.45)) {
                        proxy.scrollTo(request.id, anchor: .center)
                    }
                    highlightCoordinator.consumeScrollRequest(request)
                }
        }
    }
}

/// A segmented control styled like the clipboard panel's tab switcher.
///
/// `Picker`'s segmented style paints the selection as a flat accent-coloured
/// rectangle that snaps between segments with no transition, which looks
/// nothing like the rest of the app. This is the same control the clipboard
/// panel uses -- a soft track with one rounded selection shape that slides
/// between segments -- so settings and panels match.
struct SettingsSegmentedControl<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let label: (Item) -> String
    /// Segments share the width equally instead of sizing to their text. Used
    /// where the control is a tab bar rather than a row's right-hand control.
    var fillsWidth: Bool = false

    @Namespace private var selectionNamespace
    @State private var hovered: Item?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                segment(for: item)
            }
        }
        .padding(2)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
        // Driven from the value, not only from `withAnimation` at the tap: a
        // selection changed from anywhere else -- settings search switching
        // segments, a Defaults write from another window -- should slide too,
        // and inside a Form row the tap's transaction does not always reach
        // the row's own content.
        .animation(selectionAnimation, value: selection)
    }

    private var selectionAnimation: Animation { .spring(response: 0.32, dampingFraction: 0.82) }

    @ViewBuilder
    private func segment(for item: Item) -> some View {
        let isSelected = selection == item
        let isHovered = hovered == item

        Button {
            guard selection != item else { return }
            withAnimation(selectionAnimation) { selection = item }
        } label: {
            Text(label(item))
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(height: 24)
                .background {
                    if isSelected {
                        // The system accent colour, so the control follows
                        // System Settings > Appearance the way the stock
                        // segmented picker did.
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: "selectedSegment", in: selectionNamespace)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(0.07))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.12)) {
                if inside {
                    hovered = item
                } else if hovered == item {
                    hovered = nil
                }
            }
        }
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A settings row whose control is a ``SettingsSegmentedControl``.
///
/// Drop-in for `Picker(title, selection:).pickerStyle(.segmented)`: label on
/// the left, control on the right, same as every other row in the form.
struct SettingsSegmentedPicker<Item: Hashable>: View {
    let title: LocalizedStringKey
    @Binding var selection: Item
    let items: [Item]
    let label: (Item) -> String

    init(
        _ title: LocalizedStringKey,
        selection: Binding<Item>,
        items: [Item],
        label: @escaping (Item) -> String
    ) {
        self.title = title
        self._selection = selection
        self.items = items
        self.label = label
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 8)
            SettingsSegmentedControl(items: items, selection: $selection, label: label)
        }
    }
}

struct SettingsPermissionCallout: View {
    let title: String
    let message: String
    let icon: String
    let iconColor: Color
    let requestButtonTitle: String
    let openSettingsButtonTitle: String
    let requestAction: () -> Void
    let openSettingsAction: () -> Void

    init(
        title: String = "Accessibility permission required",
        message: String,
        icon: String = "exclamationmark.triangle.fill",
        iconColor: Color = .orange,
        requestButtonTitle: String = "Request Access",
        openSettingsButtonTitle: String = "Open Settings",
        requestAction: @escaping () -> Void,
        openSettingsAction: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.iconColor = iconColor
        self.requestButtonTitle = requestButtonTitle
        self.openSettingsButtonTitle = openSettingsButtonTitle
        self.requestAction = requestAction
        self.openSettingsAction = openSettingsAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(LocalizedStringKey(title), systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(iconColor)

            Text(LocalizedStringKey(message))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button(LocalizedStringKey(requestButtonTitle)) {
                    requestAction()
                }
                .buttonStyle(.borderedProminent)

                Button(LocalizedStringKey(openSettingsButtonTitle)) {
                    openSettingsAction()
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    HUD()
}

// MARK: - Shared badges and labels
//
// These sat at file scope in SettingsView.swift, so every pane could reach
// them. `customBadge` is used by four panes and `alphaBadge` by two, so they
// belong with the shell rather than inside whichever pane happened to hold
// them; the rest of the family follows so they stay together.

func proFeatureBadge() -> some View {
    Text("Upgrade to Pro")
        .foregroundStyle(Color(red: 0.545, green: 0.196, blue: 0.98))
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 4).stroke(Color(red: 0.545, green: 0.196, blue: 0.98), lineWidth: 1))
}

func comingSoonTag() -> some View {
    Text("Coming soon")
        .foregroundStyle(.secondary)
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .secondarySystemFill))
        .clipShape(.capsule)
}

func customBadge(text: String) -> some View {
    Text(LocalizedStringKey(text))
        .foregroundStyle(.secondary)
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .secondarySystemFill))
        .clipShape(.capsule)
}

func alphaBadge() -> some View {
    Text("ALPHA")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.9))
        )
}

func warningBadge(_ text: String, _ description: String) -> some View {
    Section {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.yellow)
            VStack(alignment: .leading) {
                Text(text)
                    .font(.headline)
                Text(description)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

/// Renders the shortcut the user actually has bound, rather than a hard-coded
/// string that silently goes stale the moment anyone rebinds it.
@MainActor
func boundShortcutDescription(for name: KeyboardShortcuts.Name) -> String? {
    KeyboardShortcuts.getShortcut(for: name)?.description
}

// MARK: - Looping video icon
//
// Used by the About pane and the Devices pane, so it cannot stay private to
// either of them.

struct SettingsLoopingVideoIcon: NSViewRepresentable {
    let url: URL
    let size: CGSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: NSRect(origin: .zero, size: size))
        view.wantsLayer = true

        let layer = AVPlayerLayer()
        layer.videoGravity = .resizeAspect
        layer.frame = view.bounds
        view.layer?.addSublayer(layer)
        context.coordinator.attach(layer: layer, url: url)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var controller: SettingsLoopingPlayerController?

        func attach(layer: AVPlayerLayer, url: URL) {
            controller = SettingsLoopingPlayerController(url: url, autoPlay: true)
            layer.player = controller?.player
        }
    }
}

private final class SettingsLoopingPlayerController {
    let player: AVQueuePlayer
    private var looper: AVPlayerLooper?

    init(url: URL, autoPlay: Bool = true) {
        let item = AVPlayerItem(url: url)
        player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none
        looper = AVPlayerLooper(player: player, templateItem: item)
        if autoPlay {
            player.play()
        }
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    deinit {
        player.pause()
        looper = nil
    }
}

/// Fetches the real app icon from the system using bundle identifiers,
/// falling back to an asset catalog image or an SF Symbol.
