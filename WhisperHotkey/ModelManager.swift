import Foundation

class ModelManager: ObservableObject {
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

    private init() {
        // Initialize _selectedModel first
        if let savedModelRawValue = UserDefaults.standard.string(forKey: "selectedModel"),
           let savedModel = ModelType(rawValue: savedModelRawValue) {
            _selectedModel = Published(initialValue: savedModel)
        } else {
            _selectedModel = Published(initialValue: .base_en) // Default fallback
        }

        createModelsDirectoryIfNeeded()
        setupAvailableModels()
        updateDownloadedModels()
        
        // After models are set up, ensure selectedModel is a downloaded one if possible
        if !downloadedModels.contains(where: { $0.type == selectedModel }) {
            if let firstDownloaded = downloadedModels.first {
                selectedModel = firstDownloaded.type
            }
        }
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
        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self, let tempURL = tempURL, error == nil else {
                return
            }

            let destinationURL = self.modelsDirectory.appendingPathComponent(modelInfo.type.rawValue)
            try? FileManager.default.moveItem(at: tempURL, to: destinationURL)

            DispatchQueue.main.async {
                self.setupAvailableModels() // Re-setup to update downloaded status and sizes
                self.selectedModel = modelInfo.type // Set as selected after download
            }
        }

        _ = task.progress.observe(\.fractionCompleted) { progress, _ in
            let now = Date().timeIntervalSince1970
            if now - self.lastProgressUpdateTime > 0.1 || progress.fractionCompleted == 1.0 { // Update every 0.1 seconds or when complete
                DispatchQueue.main.async {
                    self.downloadProgress = progress.fractionCompleted
                }
                self.lastProgressUpdateTime = now
            }
        }

        task.resume()
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
