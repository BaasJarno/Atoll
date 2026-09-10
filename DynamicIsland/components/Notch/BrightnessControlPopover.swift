/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import Defaults
import SwiftUI

/// Display brightness as a slider you can open and drag.
///
/// The notch already had a brightness slider, but only as a HUD: it appears
/// when a brightness key is pressed, needs the notch open, and disappears with
/// the sneak peek. There was no way to reach brightness without first pressing
/// the key, which is what this is for.
@MainActor
final class BrightnessControlViewModel: ObservableObject {
    @Published var level: Float = 0.5

    /// While the popover is on screen the slider has to follow the brightness
    /// keys as well as its own knob, and there is no notification to subscribe
    /// to for that -- `SystemBrightnessController.onBrightnessChange` is a
    /// single closure that `SystemChangesObserver` already owns, and taking it
    /// would silence the HUD. So this polls, and only while visible.
    private var pollTimer: Timer?

    /// A drag writes brightness continuously; reading it back in the same
    /// breath fights the knob, so polling defers until the drag settles.
    private var lastLocalChange: Date = .distantPast
    private let localChangeGrace: TimeInterval = 0.4

    func startTracking() {
        level = SystemBrightnessController.shared.currentBrightness
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollBrightness() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stopTracking() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func setLevel(_ newValue: Float) {
        let clamped = max(0, min(1, newValue))
        lastLocalChange = Date()
        level = clamped
        SystemBrightnessController.shared.setBrightness(clamped)
    }

    private func pollBrightness() {
        guard Date().timeIntervalSince(lastLocalChange) > localChangeGrace else { return }
        let current = SystemBrightnessController.shared.currentBrightness
        // A float read back from the display rounds differently than it went
        // in, so only move the knob for a change worth seeing.
        guard abs(current - level) > 0.005 else { return }
        level = current
    }

    deinit {
        pollTimer?.invalidate()
    }
}

struct BrightnessControlPopover: View {
    @StateObject private var model = BrightnessControlViewModel()

    private var percentage: String {
        "\(Int((model.level * 100).rounded()))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "sun.min.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Slider(
                    value: Binding(
                        get: { Double(model.level) },
                        set: { model.setLevel(Float($0)) }
                    ),
                    in: 0 ... 1
                )
                .tint(.accentColor)

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Display brightness")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(percentage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(16)
        .frame(width: 240)
        .onAppear { model.startTracking() }
        .onDisappear { model.stopTracking() }
    }
}
