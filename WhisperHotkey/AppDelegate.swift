import Foundation
import AppKit
import SwiftUI
import Cocoa
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var keyMonitor: KeyMonitor?
    var window: NSWindow?
    var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityAndStartMonitor()
        setupMenuBarItem()
        showMainWindow()
    }
    
    @objc func showMainWindow() {
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
    
    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil) {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
                button.contentTintColor = .labelColor
                print("DEBUG: Initial image template: \(image.isTemplate), size: \(image.size)")
            }
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Window", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        
        Transcriber.shared.$isRecording
            .sink { [weak self] isRecording in
                if let button = self?.statusItem?.button {
                    button.contentTintColor = isRecording ? .systemGreen : .labelColor
                    print("DEBUG: isRecording: \(isRecording), contentTintColor: \(String(describing: button.contentTintColor))")
                }
            }
            .store(in: &cancellables)
    }
}

class KeyMonitor {
    private var ctrlTimestamps: [TimeInterval] = []
    private var monitor: Any?
    
    init() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event: event)
        }
    }
    
    private func handle(event: NSEvent) {
        print("🟢 NSEvent received: keyCode=\(event.keyCode), flags=\(event.modifierFlags.rawValue)")
        
        // Left Ctrl = 59, Right Ctrl = 62
        guard event.keyCode == 59 || event.keyCode == 62 else { return }
        
        // We only want to handle the key-down event.
        // When a modifier key is pressed, the corresponding flag is added to modifierFlags.
        // When it's released, the flag is removed.
        // So, we check if the .control flag is present.
        guard event.modifierFlags.contains(.control) else { return }
        
        let now = Date().timeIntervalSince1970
        ctrlTimestamps.append(now)
        
        if ctrlTimestamps.count > 2 {
            ctrlTimestamps.removeFirst()
        }
        
        // If the two last presses are less than 0.5s apart, it's a double-tap.
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
