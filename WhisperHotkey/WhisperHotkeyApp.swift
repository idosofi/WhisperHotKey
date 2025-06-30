//
//  WhisperHotkeyApp.swift
//  WhisperHotkey
//
//  Created by Ido Sofi on 26/06/2025.
//

import SwiftUI
import AppKit

@main
struct WhisperHotkeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The main window is managed by AppDelegate
        Settings {
            SettingsView()
        }
    }
}


