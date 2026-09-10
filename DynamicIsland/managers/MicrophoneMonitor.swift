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
import CoreAudio
import SwiftUI
import Combine

// MARK: - CoreAudio Callback Function
// C function pointer for CoreAudio property listener
private func microphonePropertyListener(
    inObjectID: AudioObjectID,
    inNumberAddresses: UInt32,
    inAddresses: UnsafePointer<AudioObjectPropertyAddress>,
    inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let context = inClientData else { return noErr }
    let monitor = Unmanaged<MicrophoneMonitor>.fromOpaque(context).takeUnretainedValue()
    
    DispatchQueue.main.async {
        Logger.log("MicrophoneMonitor: 📢 Microphone property changed", category: .debug)
        monitor.checkMicrophoneStatus()
    }
    
    return noErr
}

@MainActor
class MicrophoneMonitor: ObservableObject {
    // MARK: - Published Properties
    @Published var isMicActive: Bool = false
    @Published var activeApp: String? = nil
    @Published var isMonitoring: Bool = false
    
    // MARK: - Private Properties
    private var defaultInputDevice: AudioDeviceID = 0
    private var isListenerRegistered: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    // Pure event-driven - no polling
    
    // MARK: - Initialization
    init() {
        // No initial setup needed
    }
    
    deinit {
        // Clean up listener synchronously
        // Remove property listener
        if isListenerRegistered, defaultInputDevice != 0 {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMaster
            )
            
            let context = Unmanaged.passUnretained(self).toOpaque()
            
            AudioObjectRemovePropertyListener(
                defaultInputDevice,
                &address,
                microphonePropertyListener,
                context
            )
        }
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring microphone usage
    func startMonitoring() {
        guard !isMonitoring else {
            Logger.log("MicrophoneMonitor: Already monitoring, skipping start", category: .warning)
            return
        }
        
        Logger.log("MicrophoneMonitor: 🟢 Starting microphone monitoring...", category: .debug)
        
        isMonitoring = true
        
        // Get default input device
        defaultInputDevice = getDefaultInputDevice()
        guard defaultInputDevice != 0 else {
            Logger.log("MicrophoneMonitor: ⚠️ No input device found", category: .debug)
            return
        }
        
        Logger.log("MicrophoneMonitor: 🎤 Found input device ID: \(defaultInputDevice)", category: .debug)
        
        // Check if property exists
        let propertyExists = checkPropertyExists()
        Logger.log("MicrophoneMonitor: Property exists: \(propertyExists)", category: .debug)
        
        // Setup event listener
        setupPropertyListener()
        
        // Check initial state
        checkMicrophoneStatus()
        
        Logger.log("MicrophoneMonitor: ✅ Started monitoring (event-driven only)", category: .debug)
    }
    
    /// Stop monitoring microphone usage
    func stopMonitoring() {
        guard isMonitoring else {
            Logger.log("MicrophoneMonitor: Not monitoring, skipping stop", category: .warning)
            return
        }
        
        Logger.log("MicrophoneMonitor: 🛑 Stopping monitoring...", category: .debug)
        
        isMonitoring = false
        
        // Remove property listener
        if isListenerRegistered {
            removePropertyListener()
        }
        
        // Reset state
        if isMicActive {
            isMicActive = false
        }
        activeApp = nil
        
        Logger.log("MicrophoneMonitor: ✅ Stopped monitoring", category: .debug)
    }
    
    /// Toggle monitoring state
    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }
    
    // MARK: - Private Methods
    
    /// Get default input device ID
    private func getDefaultInputDevice() -> AudioDeviceID {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        
        if status != noErr {
            Logger.log("MicrophoneMonitor: ⚠️ Failed to get default input device (status: \(status))", category: .error)
            return 0
        }
        
        return deviceID
    }
    
    /// Check if the property exists on the device
    private func checkPropertyExists() -> Bool {
        guard defaultInputDevice != 0 else { return false }
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )
        
        let hasProperty = AudioObjectHasProperty(defaultInputDevice, &address)
        Logger.log("MicrophoneMonitor: Device \(defaultInputDevice) has property: \(hasProperty)", category: .debug)
        
        return hasProperty
    }
    
    /// Setup CoreAudio property listener
    private func setupPropertyListener() {
        guard defaultInputDevice != 0 else { return }
        
        // Use kAudioDevicePropertyDeviceIsRunningSomewhere (tracks when device is in use anywhere)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )
        
        // Pass self as context
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        let status = AudioObjectAddPropertyListener(
            defaultInputDevice,
            &address,
            microphonePropertyListener,
            context
        )
        
        if status == noErr {
            isListenerRegistered = true
            Logger.log("MicrophoneMonitor: ✅ Property listener registered", category: .debug)
        } else {
            Logger.log("MicrophoneMonitor: ⚠️ Failed to register property listener (status: \(status))", category: .error)
        }
    }
    
    /// Remove CoreAudio property listener
    private func removePropertyListener() {
        guard defaultInputDevice != 0, isListenerRegistered else { return }
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        let status = AudioObjectRemovePropertyListener(
            defaultInputDevice,
            &address,
            microphonePropertyListener,
            context
        )
        
        if status == noErr {
            isListenerRegistered = false
            Logger.log("MicrophoneMonitor: ✅ Property listener removed", category: .debug)
        } else {
            Logger.log("MicrophoneMonitor: ⚠️ Failed to remove property listener (status: \(status))", category: .error)
        }
    }
    
    /// Check current microphone status
    func checkMicrophoneStatus() {
        guard defaultInputDevice != 0 else { return }
        
        let isRunning = isDeviceRunning(defaultInputDevice)
        
        // Debug logging
        Logger.log("MicrophoneMonitor: 🔍 Checking... current=\(isMicActive), detected=\(isRunning)", category: .debug)
        
        // Update state if changed
        if isRunning != isMicActive {
            Logger.log("MicrophoneMonitor: 🔄 State change detected (\(isMicActive) -> \(isRunning))", category: .debug)
            
            withAnimation(.smooth) {
                isMicActive = isRunning
            }
            
            if isRunning {
                Logger.log("MicrophoneMonitor: 🎤 Microphone ACTIVE", category: .debug)
                // Could try to identify app here (TODO: investigate)
                activeApp = "Unknown App"
            } else {
                Logger.log("MicrophoneMonitor: ⚪ Microphone INACTIVE", category: .debug)
                activeApp = nil
            }
        }
    }
    
    /// Check if audio device is running
    private func isDeviceRunning(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )
        
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &isRunning
        )
        
        if status != noErr {
            Logger.log("MicrophoneMonitor: ⚠️ Failed to check device running status (status: \(status))", category: .error)
            return false
        }
        
        return isRunning != 0
    }

}

// MARK: - Extensions

extension MicrophoneMonitor {
    /// Get current microphone status without async
    var currentMicStatus: Bool {
        return isMicActive
    }
    
    /// Check if monitoring is available
    var isMonitoringAvailable: Bool {
        return getDefaultInputDevice() != 0
    }
}
