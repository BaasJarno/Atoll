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

import Foundation

enum StatsFormatting {
    static func bytes(_ value: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        return formatter.string(fromByteCount: Int64(value))
    }
    
    static func mbPerSecond(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value >= 10 ? 1 : 2
        let number = NSNumber(value: value)
        let formatted = formatter.string(from: number) ?? String(format: "%.2f", value)
        return "\(formatted) MB/s"
    }

    /// A throughput reading short enough to sit on a notch card's title row,
    /// where roughly 100 points have to hold both directions: `12.3M`, `340K`,
    /// `0`. The unit is one letter and the per-second part is dropped, which
    /// the surrounding arrows or R/W labels already imply. `throughput(_:)`
    /// stays the spelled-out form for the detail panels, which have the room.
    static func compactThroughput(_ valueInMegabytesPerSecond: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        if valueInMegabytesPerSecond >= 1 {
            formatter.maximumFractionDigits = valueInMegabytesPerSecond >= 10 ? 0 : 1
            let formatted = formatter.string(from: NSNumber(value: valueInMegabytesPerSecond))
                ?? String(format: valueInMegabytesPerSecond >= 10 ? "%.0f" : "%.1f", valueInMegabytesPerSecond)
            return "\(formatted)M"
        }

        let valueInKilobytesPerSecond = valueInMegabytesPerSecond * 1024
        if valueInKilobytesPerSecond >= 1 {
            formatter.maximumFractionDigits = 0
            let formatted = formatter.string(from: NSNumber(value: valueInKilobytesPerSecond))
                ?? String(format: "%.0f", valueInKilobytesPerSecond)
            return "\(formatted)K"
        }

        return "0"
    }

    static func throughput(_ valueInMegabytesPerSecond: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        if valueInMegabytesPerSecond >= 1 {
            formatter.maximumFractionDigits = valueInMegabytesPerSecond >= 10 ? 1 : 2
            let formatted = formatter.string(from: NSNumber(value: valueInMegabytesPerSecond))
                ?? String(format: "%.2f", valueInMegabytesPerSecond)
            return "\(formatted) MB/s"
        }

        let valueInKilobytesPerSecond = valueInMegabytesPerSecond * 1024
        if valueInKilobytesPerSecond >= 1 {
            formatter.maximumFractionDigits = valueInKilobytesPerSecond >= 10 ? 0 : 1
            let formatted = formatter.string(from: NSNumber(value: valueInKilobytesPerSecond))
                ?? String(format: valueInKilobytesPerSecond >= 10 ? "%.0f" : "%.1f", valueInKilobytesPerSecond)
            return "\(formatted) KB/s"
        }

        let valueInBytesPerSecond = valueInMegabytesPerSecond * 1_048_576
        if valueInBytesPerSecond >= 1 {
            formatter.maximumFractionDigits = 0
            let formatted = formatter.string(from: NSNumber(value: valueInBytesPerSecond))
                ?? String(format: "%.0f", valueInBytesPerSecond)
            return "\(formatted) B/s"
        }

        return "0 B/s"
    }
    
    static func percentage(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
    
    static func gigabytes(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value >= 10 ? 1 : 2
        return (formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)) + " GB"
    }

    static func abbreviatedDuration(_ value: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: value) ?? "—"
    }
}
