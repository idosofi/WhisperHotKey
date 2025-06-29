import Foundation

class ModelManager: NSObject, ObservableObject {
    static let shared = ModelManager()

    enum ModelType: String, CaseIterable, Identifiable {
        case tiny_en = "ggml-tiny.en.bin"
        case base_en = "ggml-base.en.bin"
        case small_en = "ggml-small.en.bin"
        case medium_en = "ggml-medium.en.bin"
        case large_v1 = "ggml-large-v1.bin"
        case large_v2 = "ggml-large-v2.bin"
        case large_v3 = "ggml-large-v3.bin"

        var id: String { self.rawValue }
    }

    struct ModelInfo: Identifiable {
        let id = UUID()
        let type: ModelType
        var fileSize: String?
        var isDownloaded: Bool = false
    }

    @Published var availableModels: [ModelInfo] = []
    @Published var downloadedModels: [ModelInfo] = []
    @Published var downloadProgress: Double = 0
    @Published var downloadingModel: ModelType? = nil // New property to track the downloading model
    private var lastProgressUpdateTime: TimeInterval = 0
    @Published var selectedModel: ModelType {
        didSet {
            UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedModel")
            // Clear transcriber transcript when a valid model is selected
            if modelIsDownloaded(selectedModel) {
                Transcriber.shared.transcript = ""
            }
        }
    }

    var modelsDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("whisper_models")
    }

    private var urlSession: URLSession!

    private override init() {
        let initialSelectedModel: ModelType
        if let savedModelRawValue = UserDefaults.standard.string(forKey: "selectedModel"),
           let savedModel = ModelType(rawValue: savedModelRawValue) {
            initialSelectedModel = savedModel
        } else {
            initialSelectedModel = .base_en // Default fallback
        }
        _selectedModel = Published(initialValue: initialSelectedModel) // Initialize backing property before super.init()

        super.init() // Call super.init()

        createModelsDirectoryIfNeeded()
        setupAvailableModels()
        updateDownloadedModels()
        
        // After models are set up, ensure selectedModel is a downloaded one if possible
        if !downloadedModels.contains(where: { $0.type == selectedModel }) {
            if let firstDownloaded = downloadedModels.first {
                selectedModel = firstDownloaded.type
            }
        }
        
        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    private func createModelsDirectoryIfNeeded() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: modelsDirectory.path) {
            try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }

    private func setupAvailableModels() {
        availableModels = ModelType.allCases.map { type in
            ModelInfo(type: type, isDownloaded: modelIsDownloaded(type))
        }
        fetchFileSizes()
    }

    func modelIsDownloaded(_ modelType: ModelType) -> Bool {
        let fileManager = FileManager.default
        let modelPath = modelsDirectory.appendingPathComponent(modelType.rawValue).path
        return fileManager.fileExists(atPath: modelPath)
    }

    private func updateDownloadedModels() {
        downloadedModels = availableModels.filter { $0.isDownloaded }
    }

    func downloadModel(_ modelInfo: ModelInfo) {
        let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(modelInfo.type.rawValue)")!
        let task = urlSession.downloadTask(with: url)
        task.taskDescription = modelInfo.type.rawValue // Use taskDescription to identify the model in delegate methods
        task.resume()
        
        DispatchQueue.main.async {
            self.downloadingModel = modelInfo.type // Set the model being downloaded
        }
    }

    func deleteModel(_ modelType: ModelType) {
        let fileManager = FileManager.default
        let modelPath = modelsDirectory.appendingPathComponent(modelType.rawValue)

        do {
            if fileManager.fileExists(atPath: modelPath.path) {
                try fileManager.removeItem(at: modelPath)
                DispatchQueue.main.async {
                    self.setupAvailableModels() // Re-setup to update downloaded status and sizes
                    self.updateDownloadedModels()
                    if self.selectedModel == modelType {
                        // If the deleted model was the selected one, try to select another downloaded model
                        if let firstDownloaded = self.downloadedModels.first {
                            self.selectedModel = firstDownloaded.type
                        } else {
                            // Fallback to a default if no models are downloaded
                            self.selectedModel = .base_en
                        }
                    }
                }
            }
        } catch {
            print("Error deleting model \(modelType.rawValue): \(error.localizedDescription)")
        }
    }

    private func fetchFileSizes() {
        for i in 0..<availableModels.count {
            let modelType = availableModels[i].type
            let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(modelType.rawValue)")!
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"

            let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
                guard let self = self, error == nil, let httpResponse = response as? HTTPURLResponse else { return }

                if let contentLength = httpResponse.allHeaderFields["Content-Length"] as? String,
                   let size = Int(contentLength) {
                    DispatchQueue.main.async {
                        self.availableModels[i].fileSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                    }
                }
            }
            task.resume()
        }
    }
}

extension ModelManager: URLSessionDownloadDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            let now = Date().timeIntervalSince1970
            if now - self.lastProgressUpdateTime > 0.1 || progress == 1.0 {
                DispatchQueue.main.async {
                    self.downloadProgress = progress
                    print("Download Progress for \(downloadTask.taskDescription ?? "unknown"): \(progress)")
                }
                self.lastProgressUpdateTime = now
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let modelRawValue = downloadTask.taskDescription,
              let modelType = ModelType(rawValue: modelRawValue) else {
            DispatchQueue.main.async {
                self.downloadingModel = nil
            }
            return
        }

        let destinationURL = modelsDirectory.appendingPathComponent(modelType.rawValue)
        do {
            // Remove existing file if it exists before moving
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
            DispatchQueue.main.async {
                self.setupAvailableModels()
                self.selectedModel = modelType
                self.downloadingModel = nil
                self.downloadProgress = 0 // Reset progress on completion
            }
        } catch {
            print("Error moving downloaded file for \(modelType.rawValue): \(error)")
            DispatchQueue.main.async {
                self.downloadingModel = nil
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("Download task for \(task.taskDescription ?? "unknown") completed with error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.downloadingModel = nil
                self.downloadProgress = 0 // Reset progress on error
            }
        }
    }
}