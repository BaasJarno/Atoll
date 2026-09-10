/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * Originally from boring.notch project
 * Modified and adapted for Atoll (DynamicIsland)
 * See NOTICE for details.
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
import OSLog
import SwiftUI
import Defaults

enum LogCategory: String, CaseIterable {
    case lifecycle = "🔄"
    case memory = "💾"
    case performance = "⚡️"
    case ui = "🎨"
    case network = "🌐"
    case error = "❌"
    case warning = "⚠️"
    case success = "✅"
    case debug = "🔍"
    case extensions = "🧩"

    var osCategoryName: String {
        switch self {
        case .lifecycle: return "lifecycle"
        case .memory: return "memory"
        case .performance: return "performance"
        case .ui: return "ui"
        case .network: return "network"
        case .error: return "error"
        case .warning: return "warning"
        case .success: return "success"
        case .debug: return "debug"
        case .extensions: return "extensions"
        }
    }

    var defaultLevel: LogLevel {
        switch self {
        case .error: return .error
        case .warning: return .warning
        case .success, .ui, .network, .lifecycle, .memory, .performance, .extensions: return .info
        case .debug: return .debug
        }
    }
}

struct Logger {
    private static let subsystem = "com.ebullioscopic.Atoll"
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    /// One `OSLog` per category, built once.
    ///
    /// This was a `static var` dictionary filled on first use, which races:
    /// `log()` is called from whatever thread reached it — 70-odd call sites,
    /// many of them on background queues — and two of them arriving together
    /// mutated the same dictionary with no lock between them. A `static let`
    /// is initialised exactly once by the runtime (`swift_once`) and never
    /// written again, so the race goes away without a lock to pay for on
    /// every line logged. The category list is finite, so eager construction
    /// costs a handful of objects at first use.
    private static let osLoggers: [LogCategory: OSLog] = Dictionary(
        uniqueKeysWithValues: LogCategory.allCases.map { category in
            (category, OSLog(subsystem: subsystem, category: category.osCategoryName))
        }
    )

    private static func osLogger(for category: LogCategory) -> OSLog {
        osLoggers[category] ?? .default
    }

    static func log(
        _ message: String,
        category: LogCategory,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        let entry = "\(category.rawValue) [\(timestamp)] [\(fileName):\(line)] \(function) - \(message)"

#if DEBUG
        // A debug build is someone sitting at a console, so they see the line
        // whatever the setting says. `logLevel` decides what a shipped build
        // records, which is the thing worth having a setting for.
        //
        // This used to sit behind the level check below, and since the level
        // defaults to `.none`, a debug build printed nothing at all through
        // this function — which is the most likely reason several hundred
        // `print` calls grew up beside it.
        Swift.print(entry)
#endif

        let configuredLevel = Defaults[.logLevel]
        guard configuredLevel != .none,
              category.defaultLevel.rawValue <= configuredLevel.rawValue else {
            return
        }
        os_log("%{public}@", log: osLogger(for: category), type: .default, entry)
    }
    
    static func trackMemory(
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            log(String(format: "Memory used: %.2f MB", usedMB),
                category: .memory,
                file: file,
                function: function,
                line: line)
        }
    }
}

extension View {
    func trackLifecycle(_ identifier: String) -> some View {
        self.modifier(ViewLifecycleTracker(identifier: identifier))
    }
}

struct ViewLifecycleTracker: ViewModifier {
    let identifier: String
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                Logger.log("\(identifier) appeared", category: .lifecycle)
                Logger.trackMemory()
            }
            .onDisappear {
                Logger.log("\(identifier) disappeared", category: .lifecycle)
                Logger.trackMemory()
            }
    }
}

// Global overrides to filter scattered print and NSLog statements throughout the app

public func NSLog(_ format: String, _ args: CVarArg...) {
    let configuredLevel = Defaults[.logLevel]
    if configuredLevel == .none { return }
    
    let message = String(format: format, arguments: args)
    let lowerMessage = message.lowercased()
    
    let isError = message.contains("❌") || lowerMessage.contains("error") || lowerMessage.contains("failed")
    let isWarning = message.contains("⚠️") || lowerMessage.contains("warning")
    
    let simulatedLevel: LogLevel = isError ? .error : (isWarning ? .warning : .debug)
    
    if simulatedLevel.rawValue > configuredLevel.rawValue { return }
    
    Foundation.NSLog("%@", message)
} 