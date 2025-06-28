//
//  ContentView.swift
//  WhisperHotkey
//
//  Created by Ido Sofi on 26/06/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject var transcriber = Transcriber.shared
    @StateObject var modelManager = ModelManager.shared
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                if modelManager.selectedModelId == nil || !modelManager.downloadedModels[modelManager.selectedModelId!, default: false] {
                    Spacer()
                    Text("No Whisper model selected or downloaded.")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    NavigationLink(destination: SettingsView()) {
                        Text("Go to Settings to Download Model")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        Text(transcriber.transcript)
                            .padding()
                    }
                    Spacer()
                    Button(transcriber.isRecording ? "🛑 Stop Recording" : "🎤 Start Recording") {
                        transcriber.toggleRecording()
                    }
                    .padding()
                }
            }
            .padding()
            .navigationTitle("Whisper Hotkey")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }
}
