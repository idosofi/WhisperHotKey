import Foundation
import AppKit
import SwiftUI
import Cocoa

import AppKit
import SwiftUI
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var keyMonitor: KeyMonitor?
    var window: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityAndStartMonitor()
        showMainWindow()
    }
    
    func showMainWindow() {
        if window == nil {
            let contentView = ContentView()
            let hostingController = NSHostingController(rootView: contentView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Whisper Dictation"
            window.setContentSize(NSSize(width: 420, height: 300))
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.center()
            window.isReleasedWhenClosed = false
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func requestAccessibilityAndStartMonitor() {
        // 🪵 Debug logs to verify running bundle info
        print("🔍 Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")
        print("🔍 Executable path: \(Bundle.main.executablePath ?? "nil")")
        
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if trusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.keyMonitor = KeyMonitor()
            }
        } else {
            print("⚠️ Accessibility permission not granted.")
        }
    }
}

class KeyMonitor {
    private var ctrlTimestamps: [TimeInterval] = []
    private var monitor: Any?
    
    init() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event: event)
        }
    }
    
    private func handle(event: NSEvent) {
        print("🟢 NSEvent received: keyCode=\(event.keyCode), flags=\(event.modifierFlags.rawValue)")
        
        // Left Ctrl = 59, Right Ctrl = 62
        guard event.keyCode == 59 || event.keyCode == 62 else { return }
        
        let now = Date().timeIntervalSince1970
        ctrlTimestamps.append(now)
        
        if ctrlTimestamps.count > 2 {
            ctrlTimestamps.removeFirst()
        }
        
        if ctrlTimestamps.count == 2, ctrlTimestamps[1] - ctrlTimestamps[0] < 0.5 {
            print("⏹ Double Ctrl Detected")
            Transcriber.shared.toggleRecording()
            ctrlTimestamps.removeAll()
        }
    }
    
    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
