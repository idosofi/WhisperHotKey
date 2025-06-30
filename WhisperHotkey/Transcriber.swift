import Foundation
import SwiftUI
import AVFoundation
import Combine
import whisper
import AppKit // For NSSound

class Transcriber: ObservableObject {
    static let shared = Transcriber()
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    
    var selectedModel: ModelManager.ModelType {
        return modelManager.selectedModel
    }
    
    private var audioEngine: AVAudioEngine?
    private var audioBuffer = [Float]() // Buffer to store audio data
    private var whisperContext: OpaquePointer?
    private var cancellables = Set<AnyCancellable>()
    private var modelManager = ModelManager.shared
    
    private let startSound = NSSound(named: "Funk")
    private let stopSound = NSSound(named: "Pop")
    
    init() {
        // Load the initial selected model
        loadWhisperModel(model: modelManager.selectedModel)

        modelManager.$selectedModel
            .sink { [weak self] newModel in
                self?.loadWhisperModel(model: newModel)
            }
            .store(in: &cancellables)
    }
    
    private func loadWhisperModel(model: ModelManager.ModelType) {
        if let context = whisperContext {
            whisper_free(context)
            whisperContext = nil
        }
        
        let modelPath = modelManager.modelsDirectory.appendingPathComponent(model.rawValue).path
        
        if modelManager.modelIsDownloaded(model) {
            var params = whisper_context_default_params()
            params.use_gpu = false // Explicitly disable GPU usage
            whisperContext = whisper_init_from_file_with_params(modelPath, params)
            
            if whisperContext == nil {
                DispatchQueue.main.async {
                    self.transcript = "Error: Failed to initialize Whisper model from \(model.rawValue). Check model integrity."
                }
            }
        } else {
            DispatchQueue.main.async {
                self.transcript = "To start, please download a model from Settings."
            }
        }
    }
    
    func toggleRecording() {
        if isRecording {
            Task { await stopAndTranscribe() }
        } else {
            Task { await startRecording() }
        }
    }
    
    func startRecording() async {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            // Handle granted status if needed
        }
        
        // Setup audio engine for recording
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        print("DEBUG: Hardware Audio Format - Sample Rate: \(inputFormat.sampleRate), Channels: \(inputFormat.channelCount), Format: \(inputFormat.commonFormat.rawValue)")

        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        
        audioBuffer.removeAll() // Clear previous audio data

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { (buffer, time) in
            if inputFormat.isEqual(outputFormat) {
                // No conversion needed
                if let floatChannelData = buffer.floatChannelData?[0] {
                    let frameLength = Int(buffer.frameLength)
                    self.audioBuffer.append(contentsOf: Array(UnsafeBufferPointer(start: floatChannelData, count: frameLength)))
                }
            } else {
                // Convert to 16kHz, mono, float32
                if let converter = AVAudioConverter(from: inputFormat, to: outputFormat) {
                    let ratio = outputFormat.sampleRate / inputFormat.sampleRate
                    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
                    
                    let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity)!
                    convertedBuffer.frameLength = 0 // Reset frameLength before conversion

                    let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                        outStatus.pointee = AVAudioConverterInputStatus.haveData
                        return buffer
                    }

                    var error: NSError?
                    let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

                    if status == .error {
                        print("Error converting audio: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }

                    if let floatChannelData = convertedBuffer.floatChannelData?[0] {
                        let frameLength = Int(convertedBuffer.frameLength)
                        self.audioBuffer.append(contentsOf: Array(UnsafeBufferPointer(start: floatChannelData, count: frameLength)))
                    }
                }
            }
        }
        
        do {
            try audioEngine!.start()
            await MainActor.run {
                isRecording = true
                startSound?.play()
            }
        } catch {
            await MainActor.run {
                isRecording = false
                transcript = "⚠️ Failed to start recording: \(error.localizedDescription)"
            }
        }
    }
    
    func stopAndTranscribe() async {
        await MainActor.run { isRecording = false }
        stopSound?.play()
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // Perform transcription using whisper.cpp
        guard let context = whisperContext else {
            await MainActor.run {
                transcript = "Error: Whisper model not loaded."
            }
            return
        }
        
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.language = ("en" as NSString).utf8String // Set language to English
        
        // You might need to set other parameters based on your needs
        // params.print_realtime = true;
        // params.print_progress = false;
        // params.print_timestamps = true;
        // params.print_special = false;
        // params.translate = false;
        // params.n_threads = 6;
        // params.offset_ms = 0;
        // params.duration_ms = 0;
        
        // Pass the accumulated audio data to whisper_full
        whisper_full(context, params, audioBuffer, Int32(audioBuffer.count))
        
        let rawTranscript = (0..<whisper_full_n_segments(context)).compactMap { i in
            if let cText = whisper_full_get_segment_text(context, Int32(i)) {
                return String(cString: cText)
            }
            return nil
        }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let finalTranscript = isNonSpeech(transcript: rawTranscript) ? "" : rawTranscript
        
        await MainActor.run { [self, finalTranscript] in
            self.transcript = finalTranscript
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(finalTranscript, forType: .string)
            
            if !finalTranscript.isEmpty {
                simulatePaste()
            }
        }
    }
    
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Command down
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        cmdDown?.flags = .maskCommand
        cmdDown?.post(tap: .cgAnnotatedSessionEventTap)

        // V down
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        vDown?.post(tap: .cgAnnotatedSessionEventTap)

        // V up
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        vUp?.post(tap: .cgAnnotatedSessionEventTap)

        // Command up
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        cmdUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
    
    func listMicDevices() {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        
        for _ in session.devices {
            // No logging here as per previous instruction
        }
    }
    
    private func isNonSpeech(transcript: String) -> Bool {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Common patterns for non-speech in Whisper output
        let nonSpeechPatterns = [
            "^\\[.*\\]$", // [something]
            "^\\(.*?\\)$", // (something)
            "♪",         // Music note
            "chimes",
            "chuckling",
            "silence",
            "BLANK_AUDIO"
        ]
        
        for pattern in nonSpeechPatterns {
            if trimmedTranscript.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        // Consider very short transcripts as potential non-speech artifacts if they don't contain alphanumeric characters
        if trimmedTranscript.count < 3 && trimmedTranscript.rangeOfCharacter(from: .alphanumerics) == nil {
                return true
            }
        
        return false
    }
    
    deinit {
        if let context = whisperContext {
            whisper_free(context)
        }
    }
}

