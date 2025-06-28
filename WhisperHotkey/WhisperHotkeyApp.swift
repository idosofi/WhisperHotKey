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
    @State private var isShowingSettingsSheet = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if ModelManager.shared.modelIsDownloaded(ModelManager.shared.selectedModel) {
                    ContentView()
                } else {
                    Text("Please select and download a model in Settings.")
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding()
                        .onAppear { isShowingSettingsSheet = true }
                }
            }
            .sheet(isPresented: $isShowingSettingsSheet) {
                SettingsView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
                isShowingSettingsSheet = true
            }
        }
    }
}


