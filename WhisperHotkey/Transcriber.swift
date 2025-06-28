//
//  Transcriber.swift
//  WhisperHotkey
//
//  Created by Ido Sofi on 26/06/2025.
//

import Foundation
import SwiftUI
import AVFoundation

class Transcriber: ObservableObject {
    static let shared = Transcriber()
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    private var tempFile: URL?
    private var soxProcess: Process?
    
    func toggleRecording() {
        if isRecording {
            Task { await stopAndTranscribe() }
        } else {
            Task { await startRecording() }
        }
    }
    
    func startRecording() async {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            print("Mic access granted: \(granted)")
        }
        
        listMicDevices()
        // 👇 Trigger macOS microphone permission prompt if not already granted
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )
        _ = session.devices.first
        print("Mic devices: \(session.devices)")

        
        await MainActor.run {
            isRecording = true
            transcript = "Recording... (Double Ctrl to stop)"
        }
        
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("input.wav")
        tempFile = temp
        
        let task = Process()
        task.launchPath = "/opt/homebrew/bin/sox"
        task.arguments = ["-t", "coreaudio", "default", "-c", "1", "-r", "16000", "-b", "16", temp.path]
        soxProcess = task
        
        do {
            print("Launching SoX: \(task.launchPath ?? "nil") \(task.arguments?.joined(separator: " ") ?? "")")
            try task.run()
        } catch {
            await MainActor.run {
                isRecording = false
                print("⚠️ Failed to start recording: \(error.localizedDescription)")
                transcript = "⚠️ Failed to start recording: \(error.localizedDescription)"
            }
            soxProcess = nil
        }
    }
    
    func stopAndTranscribe() async {
        await MainActor.run { isRecording = false }
        
        if let process = soxProcess, process.isRunning {
            process.terminate()
        }
        soxProcess = nil
        
        guard let temp = tempFile else { return }
        
        let task = Process()
        task.launchPath = "/opt/homebrew/bin/whisper-cpp"
        task.arguments = [
            "--model", "\(NSHomeDirectory())/.whispercpp/models/ggml-small.en.bin",
            "--file", temp.path,
            "--output-txt"
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        try? task.run()
        task.waitUntilExit()
        
        let outputPath = temp.appendingPathExtension("txt")
        if let contents = try? String(contentsOf: outputPath) {
            await MainActor.run {
                self.transcript = contents
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(contents, forType: .string)
            }
        }
    }
    
    func listMicDevices() {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        
        for device in session.devices {
            print("🔊 Device: \(device.localizedName)")
        }
    }
}
