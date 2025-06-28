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
    @State private var showingSettingsOnLaunch = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if ModelManager.shared.downloadedModels.isEmpty {
                        showingSettingsOnLaunch = true
                    }
                }
                .sheet(isPresented: $showingSettingsOnLaunch) {
                    SettingsView()
                }
        }
    }
}
