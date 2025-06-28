//
//  ContentView.swift
//  WhisperHotkey
//
//  Created by Ido Sofi on 26/06/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject var transcriber = Transcriber.shared
    @State private var showingSettings = false
    
    var body: some View {
        VStack(alignment: .leading) {
            ScrollView {
                Text(transcriber.transcript)
                    .padding()
            }
            Spacer()
            HStack {
                Button(transcriber.isRecording ? "🛑 Stop Recording" : "🎤 Start Recording") {
                    transcriber.toggleRecording()
                }
                .padding()
                
                Spacer()
                
                Button("Settings") {
                    showingSettings.toggle()
                }
                .padding()
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
            }
        }
        .padding()
    }
}
