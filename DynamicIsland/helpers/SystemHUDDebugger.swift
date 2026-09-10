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

class SystemHUDDebugger {
    
    /// Test system HUD functionality and print status
    public static func testSystemHUD() {
        Logger.log("\n🔍 === System HUD Debug Report ===", category: .debug)
        
        // Check current OSDUIHelper status
        let isRunning = SystemOSDManager.isOSDUIHelperRunning()
        print("📊 OSDUIHelper Status: \(isRunning ? "✅ Running" : "❌ Not running")")
        
        // Test disable
        Logger.log("Testing disable...", category: .debug)
        SystemOSDManager.disableSystemHUD()
        
        // Wait and check
        usleep(500000)
        let isRunningAfterDisable = SystemOSDManager.isOSDUIHelperRunning()
        print("📊 After disable: \(isRunningAfterDisable ? "✅ Running (stopped)" : "❌ Not running")")
        
        // Test enable
        Logger.log("Testing re-enable...", category: .debug)
        SystemOSDManager.enableSystemHUD()
        
        // Wait and check
        usleep(1000000)
        let isRunningAfterEnable = SystemOSDManager.isOSDUIHelperRunning()
        print("📊 After re-enable: \(isRunningAfterEnable ? "✅ Running" : "❌ Not running")")
        
        Logger.log("=== End Debug Report ===\n", category: .debug)
        
        if !isRunningAfterEnable {
            Logger.log("WARNING: System HUD may not be working properly!", category: .warning)
            Logger.log("Try pressing volume keys to test system HUD functionality", category: .debug)
        }
    }
    
    /// Force restart OSDUIHelper using multiple methods
    public static func forceRestartOSDUIHelper() {
        Logger.log("Force restarting OSDUIHelper...", category: .lifecycle)
        
        // Method 1: Kill and kickstart
        SystemOSDManager.enableSystemHUD()
        
        // Method 2: Try launchctl bootstrap (more aggressive)
        do {
            let bootstrap = Process()
            bootstrap.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            bootstrap.arguments = ["bootstrap", "gui/\(getuid())", "/System/Library/LaunchAgents/com.apple.OSDUIHelper.plist"]
            try bootstrap.run()
            bootstrap.waitUntilExit()
            Logger.log("Bootstrap method completed", category: .success)
        } catch {
            Logger.log("Bootstrap method failed: \(error)", category: .error)
        }
        
        // Method 3: Try direct service restart
        do {
            let restart = Process()
            restart.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            restart.arguments = ["restart", "gui/\(getuid())/com.apple.OSDUIHelper"]
            try restart.run()
            restart.waitUntilExit()
            Logger.log("Restart method completed", category: .success)
        } catch {
            Logger.log("Restart method failed: \(error)", category: .error)
        }
        
        // Check final status
        usleep(1000000)
        let finalStatus = SystemOSDManager.isOSDUIHelperRunning()
        print("📊 Final OSDUIHelper status: \(finalStatus ? "✅ Running" : "❌ Not running")")
    }
}