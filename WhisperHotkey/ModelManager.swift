import Foundation

class ModelManager: ObservableObject {
    static let shared = ModelManager()

    enum Model: String, CaseIterable, Identifiable {
        case tiny_en = "ggml-tiny.en.bin"
        case base_en = "ggml-base.en.bin"
        case small_en = "ggml-small.en.bin"
        case medium_en = "ggml-medium.en.bin"
        case large_v1 = "ggml-large-v1.bin"
        case large_v2 = "ggml-large-v2.bin"
        case large_v3 = "ggml-large-v3.bin"

        var id: String { self.rawValue }
    }

    @Published var availableModels: [Model] = Model.allCases
    @Published var downloadedModels: [Model] = []
    @Published var downloadProgress: Double = 0

    private var modelsDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("whisper_models")
    }

    private init() {
        createModelsDirectoryIfNeeded()
        updateDownloadedModels()
    }

    private func createModelsDirectoryIfNeeded() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: modelsDirectory.path) {
            try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }

    func modelIsDownloaded(_ model: Model) -> Bool {
        let fileManager = FileManager.default
        let modelPath = modelsDirectory.appendingPathComponent(model.rawValue).path
        return fileManager.fileExists(atPath: modelPath)
    }

    private func updateDownloadedModels() {
        downloadedModels = availableModels.filter { modelIsDownloaded($0) }
    }

    func downloadModel(_ model: Model) {
        let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(model.rawValue)")!
        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self, let tempURL = tempURL, error == nil else {
                return
            }

            let destinationURL = self.modelsDirectory.appendingPathComponent(model.rawValue)
            try? FileManager.default.moveItem(at: tempURL, to: destinationURL)

            DispatchQueue.main.async {
                self.updateDownloadedModels()
            }
        }

        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                self.downloadProgress = progress.fractionCompleted
            }
        }

        task.resume()
    }
}