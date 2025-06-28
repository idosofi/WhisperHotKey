//
//  ContentView.swift
//  WhisperHotkey
//
//  Created by Ido Sofi on 26/06/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject var transcriber = Transcriber.shared
    
    var body: some View {
        VStack(alignment: .leading) {
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
        .padding()
    }
}
