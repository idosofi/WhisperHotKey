import Foundation
import AppKit
import SwiftUI
import Cocoa
import Combine

extension Notification.Name {
    static let showSettings = Notification.Name("showSettings")
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var hasShownAccessibilityAlert = false
    var keyMonitor: KeyMonitor?
    var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    
    var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = ModelManager.shared // Initialize ModelManager
        setupMenuBarItem()
        
        // Set the activation policy to accessory to keep the app running in the background
        NSApp.setActivationPolicy(.accessory)

        // Create the main window
        let hostingController = NSHostingController(rootView: ContentView().frame(width: 400, height: 300))
        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        mainWindow?.center()
        mainWindow?.setFrameAutosaveName("MainWindow")
        mainWindow?.contentView = hostingController.view
        mainWindow?.delegate = self // Set the delegate
        mainWindow?.makeKeyAndOrderFront(nil)
        checkAccessibilityAndSetupMonitor()
    }
    
    // MARK: - NSWindowDelegate
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil) // Hide the window
        return false // Prevent the window from being closed and deallocated
    }
    
    private func checkAccessibilityAndSetupMonitor() {
        let trusted = AXIsProcessTrusted()
        
        if trusted {
            // If trusted, set up the key monitor
            self.keyMonitor = KeyMonitor()
        } else {
            // If not trusted, show the alert only once per session
            if !hasShownAccessibilityAlert {
                showAccessibilityAlert()
                hasShownAccessibilityAlert = true
            }
        }
    }
    
    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "WhisperHotkey needs accessibility access to monitor keyboard shortcuts. Please enable it in System Settings."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
            // Do not terminate the app. User will grant permission and return.
        } else {
            NSApp.terminate(nil)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
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
        menu.addItem(NSMenuItem(title: "Show Window", action: #selector(showMainWindow), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        
        Transcriber.shared.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                guard let button = self?.statusItem?.button else { return }
                
                if let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil) {
                    image.size = NSSize(width: 18, height: 18)
                    image.isTemplate = !isRecording
                    button.image = image
                    button.contentTintColor = isRecording ? .systemGreen : nil
                }
            }
            .store(in: &cancellables)
    }
    
    @objc func showMainWindow() {
        if mainWindow == nil {
            // Re-create the main window if it's been closed
            let hostingController = NSHostingController(rootView: ContentView().frame(width: 400, height: 300))
            mainWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            mainWindow?.center()
            mainWindow?.setFrameAutosaveName("MainWindow")
            mainWindow?.contentView = hostingController.view
            mainWindow?.delegate = self // Set the delegate
        }
        
        self.mainWindow?.setIsVisible(true)
        NSApp.activate(ignoringOtherApps: true)
        self.mainWindow?.makeKeyAndOrderFront(nil)
        if self.mainWindow?.isMiniaturized ?? false {
            self.mainWindow?.deminiaturize(nil)
        }
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



