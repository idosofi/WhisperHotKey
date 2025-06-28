//
//  Transcriber.swift
//  WhisperHotkey
//
//  Created by Ido Sofi on 26/06/2025.
//

import Foundation
import SwiftUI
import AVFoundation
import Whisper

class Transcriber: ObservableObject {
    static let shared = Transcriber()
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    
    private var audioEngine: AVAudioEngine!
    private var audioFile: AVAudioFile!
    private var whisperContext: WhisperContext?
    
    func toggleRecording() {
        if isRecording {
            Task { await stopAndTranscribe() }
        } else {
            Task { await startRecording() }
        }
    }
    
    func startRecording() async {
        await MainActor.run {
            isRecording = true
            transcript = "Recording... (Double Ctrl to stop)"
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            await MainActor.run {
                isRecording = false
                transcript = "⚠️ Failed to set up audio session: \(error.localizedDescription)"
            }
            return
        }

        audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        let tempDir = FileManager.default.temporaryDirectory
        let tempWavFile = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")

        do {
            audioFile = try AVAudioFile(forWriting: tempWavFile, settings: recordingFormat.settings)
        } catch {
            await MainActor.run {
                isRecording = false
                transcript = "⚠️ Failed to create audio file: \(error.localizedDescription)"
            }
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, time) in
            guard let self = self else { return }
            do {
                try self.audioFile.write(from: buffer)
            } catch {
                // Handle error writing to file
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            await MainActor.run {
                isRecording = false
                transcript = "⚠️ Failed to start audio engine: \(error.localizedDescription)"
            }
        }
    }
    
    func stopAndTranscribe() async {
        await MainActor.run { isRecording = false }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        guard let audioFile = audioFile else { return }
        let audioFilePath = audioFile.url
        self.audioFile = nil // Release the file handle

        let modelManager = ModelManager.shared
        guard let selectedModelId = modelManager.selectedModelId,
              let selectedModel = modelManager.availableModels.first(where: { $0.id == selectedModelId }) else {
            await MainActor.run {
                self.transcript = "⚠️ No Whisper model selected or available. Please go to settings to download one."
            }
            return
        }
        let modelPath = modelManager.modelPath(for: selectedModel).path

        do {
            whisperContext = try WhisperContext.createContext(path: modelPath)
            let data = try Data(contentsOf: audioFilePath)
            let floats = data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> [Float] in
                Array(UnsafeBufferPointer(start: buffer.baseAddress!.assumingMemoryBound(to: Float.self), count: buffer.count / MemoryLayout<Float>.size))
            }

            try await whisperContext?.fullTranscribe(audio: floats)
            let text = (0..<whisperContext!.fullNSegments()).map { whisperContext!.fullText(segment: $0) }.joined(separator: " ")

            await MainActor.run {
                self.transcript = text
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        } catch {
            await MainActor.run {
                self.transcript = "⚠️ Transcription failed: \(error.localizedDescription)"
            }
        }

        // Clean up temporary audio file
        try? FileManager.default.removeItem(at: audioFilePath)
    }
    
    
}
