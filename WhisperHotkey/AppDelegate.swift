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
        
        
        
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if trusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.keyMonitor = KeyMonitor()
            }
        } else {
            
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
                
            }
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Window", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        
        Transcriber.shared.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                guard let button = self?.statusItem?.button else { return }
                
                if let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil) {
                    image.size = NSSize(width: 18, height: 18)
                    image.isTemplate = !isRecording  // 🟢 Use native macOS style when OFF
                    button.image = image
                    button.contentTintColor = isRecording ? .systemGreen : nil  // ✅ Green when ON, system-default when OFF
                }
            }
            .store(in: &cancellables)
    }
}

class KeyMonitor {
    private var ctrlTimestamps: [TimeInterval] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    init() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event: event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event: event)
            return event
        }
    }
    
    private func handle(event: NSEvent) {
        
        
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
            
            Transcriber.shared.toggleRecording()
            ctrlTimestamps.removeAll()
        }
    }
    
    deinit {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }
}
