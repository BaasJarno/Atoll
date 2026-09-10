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

import AppKit
import SwiftUI
import Foundation

// MARK: - Simplified Screenshot Tool (Based on ScreenshotApp Research)
class ScreenshotSnippingTool: NSObject, ObservableObject {
    static let shared = ScreenshotSnippingTool()
    
    @Published var isSnipping = false
    private var completion: ((URL) -> Void)?
    
    // MARK: - Screenshot Types (Based on ScreenshotApp)
    enum ScreenshotType {
        case full
        case window
        case area
        
        var processArguments: [String] {
            switch self {
            case .full:
                return ["-c"] // -c = clipboard
            case .window:
                return ["-cw"] // -c = clipboard, -w = window selection
            case .area:
                return ["-cs"] // -c = clipboard, -s = area selection
            }
        }
        
        var displayName: String {
            switch self {
            case .full: return "Full Screen"
            case .window: return "Window"
            case .area: return "Area"
            }
        }
        
        var iconName: String {
            switch self {
            case .full: return "rectangle.dashed"
            case .window: return "macwindow"
            case .area: return "viewfinder.rectangular"
            }
        }
    }
    
    enum ScreenshotError: Error {
        case captureFailed
        case noImageInPasteboard
        case saveFailed
    }
    
    override init() {
        super.init()
    }
    
    // MARK: - Enhanced API (Based on ScreenshotApp Implementation)
    func startSnipping(type: ScreenshotType = .area, completion: @escaping (URL) -> Void) {
        guard !isSnipping else { return }
        
        Logger.log("ScreenshotTool: Starting \(type.displayName.lowercased()) screenshot using screencapture tool", category: .debug)
        self.completion = completion
        isSnipping = true
        
        // Use the same approach as ScreenshotApp - direct screencapture command
        takeScreenshot(type: type)
    }
    
    // MARK: - Convenience Methods for Different Types
    func startAreaScreenshot(completion: @escaping (URL) -> Void) {
        startSnipping(type: .area, completion: completion)
    }
    
    func startFullScreenshot(completion: @escaping (URL) -> Void) {
        startSnipping(type: .full, completion: completion)
    }
    
    func startWindowScreenshot(completion: @escaping (URL) -> Void) {
        startSnipping(type: .window, completion: completion)
    }
    
    // MARK: - ScreenshotApp-Style Implementation
    private func takeScreenshot(type: ScreenshotType) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = type.processArguments
        
        do {
            print("📸 ScreenshotTool: Running screencapture \(type.processArguments.joined(separator: " ")) command")
            try task.run()
            task.waitUntilExit()
            
            // Process completed - check if successful
            if task.terminationStatus == 0 {
                Logger.log("ScreenshotTool: screencapture completed successfully", category: .success)
                getImageFromPasteboard()
            } else {
                Logger.log("ScreenshotTool: screencapture failed with status: \(task.terminationStatus)", category: .error)
                finishSnipping()
            }
            
        } catch {
            Logger.log("ScreenshotTool: Failed to run screencapture: \(error)", category: .error)
            finishSnipping()
        }
    }
    
    // MARK: - Pasteboard Integration (ScreenshotApp Pattern)
    private func getImageFromPasteboard() {
        Logger.log("ScreenshotTool: Checking pasteboard for screenshot", category: .debug)
        
        guard NSPasteboard.general.canReadItem(withDataConformingToTypes: NSImage.imageTypes) else {
            Logger.log("ScreenshotTool: No image data in pasteboard", category: .error)
            finishSnipping()
            return
        }
        
        guard let image = NSImage(pasteboard: NSPasteboard.general) else {
            Logger.log("ScreenshotTool: Failed to create NSImage from pasteboard", category: .error)
            finishSnipping()
            return
        }
        
        Logger.log("ScreenshotTool: Got image from pasteboard: \(image.size)", category: .success)
        saveImageAndComplete(image: image)
    }
    
    // MARK: - Image Saving
    private func saveImageAndComplete(image: NSImage) {
        let filename = "screenshot_\(Int(Date().timeIntervalSince1970)).png"
        let screenshotDir = ScreenAssistantManager.screenshotDataDirectory
        
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: screenshotDir.path) {
            try? FileManager.default.createDirectory(at: screenshotDir, withIntermediateDirectories: true)
        }
        
        let screenshotURL = screenshotDir.appendingPathComponent(filename)
        
        // Convert NSImage to PNG data
        guard let imageData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: imageData),
              let pngData = bitmapRep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            Logger.log("ScreenshotTool: Failed to convert image to PNG", category: .error)
            finishSnipping()
            return
        }
        
        do {
            try pngData.write(to: screenshotURL)
            Logger.log("ScreenshotTool: Screenshot saved to: \(screenshotURL.path)", category: .success)
            
            // Execute completion callback
            let callback = self.completion
            self.completion = nil
            finishSnipping()
            
            // Call completion on main thread
            DispatchQueue.main.async {
                callback?(screenshotURL)
            }
            
        } catch {
            Logger.log("ScreenshotTool: Failed to save image: \(error)", category: .error)
            finishSnipping()
        }
    }
    
    // MARK: - State Management
    private func finishSnipping() {
        Logger.log("ScreenshotTool: Finishing snipping process", category: .lifecycle)
        
        DispatchQueue.main.async {
            self.isSnipping = false
            self.completion = nil
            Logger.log("ScreenshotTool: Snipping process completed", category: .success)
        }
    }
    
    func cancelSnipping() {
        Logger.log("ScreenshotTool: Snipping cancelled", category: .error)
        finishSnipping()
    }
}

