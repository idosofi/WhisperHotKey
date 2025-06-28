
import Foundation
import Combine

struct WhisperModel: Identifiable, Codable {
    let id: String
    let name: String
    let size: String
    let url: URL
}

class ModelManager: ObservableObject {
    static let shared = ModelManager()

    @Published var availableModels: [WhisperModel] = [
        WhisperModel(id: "tiny.en", name: "Tiny (English)", size: "30 MB", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin")!),
        WhisperModel(id: "base.en", name: "Base (English)", size: "75 MB", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")!),
        WhisperModel(id: "small.en", name: "Small (English)", size: "244 MB", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin")!),
        WhisperModel(id: "medium.en", name: "Medium (English)", size: "769 MB", url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin")!)
    ]

    @Published var selectedModelId: String? {
        didSet {
            UserDefaults.standard.set(selectedModelId, forKey: "selectedWhisperModelId")
        }
    }

    @Published var downloadProgress: [String: Double] = [:]
    @Published var isDownloading: [String: Bool] = [:]
    @Published var downloadedModels: [String: Bool] = [:]

    private var cancellables = Set<AnyCancellable>()

    private init() {
        selectedModelId = UserDefaults.standard.string(forKey: "selectedWhisperModelId")
        loadDownloadedModelsStatus()
    }

    func modelPath(for model: WhisperModel) -> URL {
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDirectory = appSupportDirectory.appendingPathComponent("WhisperModels")
        if !FileManager.default.fileExists(atPath: modelsDirectory.path) {
            try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        return modelsDirectory.appendingPathComponent(model.url.lastPathComponent)
    }

    func downloadModel(_ model: WhisperModel) {
        guard !isDownloading[model.id, default: false] else { return }

        isDownloading[model.id] = true
        downloadProgress[model.id] = 0.0

        let destinationUrl = modelPath(for: model)

        let task = URLSession.shared.downloadTask(with: model.url) { [weak self] location, response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isDownloading[model.id] = false
                if let location = location, error == nil {
                    do {
                        if FileManager.default.fileExists(atPath: destinationUrl.path) {
                            try FileManager.default.removeItem(at: destinationUrl)
                        }
                        try FileManager.default.moveItem(at: location, to: destinationUrl)
                        self.downloadedModels[model.id] = true
                        if self.selectedModelId == nil {
                            self.selectedModelId = model.id
                        }
                    } catch {
                        // Handle error
                    }
                } else {
                    // Handle error
                }
            }
        }

        task.progress.publisher
            .receive(on: DispatchQueue.main)
            .sink { progress in
                self.downloadProgress[model.id] = progress.fractionCompleted
            }
            .store(in: &cancellables)

        task.resume()
    }

    func isModelDownloaded(_ model: WhisperModel) -> Bool {
        return FileManager.default.fileExists(atPath: modelPath(for: model).path)
    }

    private func loadDownloadedModelsStatus() {
        for model in availableModels {
            downloadedModels[model.id] = isModelDownloaded(model)
        }
    }
}
