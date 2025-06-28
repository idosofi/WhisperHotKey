import SwiftUI

struct SettingsView: View {
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var transcriber = Transcriber.shared

    var body: some View {
        VStack {
            Text("Model Management")
                .font(.title)

            Picker("Selected Model", selection: $transcriber.selectedModel) {
                ForEach(modelManager.availableModels) { model in
                    Text(model.rawValue)
                        .tag(model)
                }
            }
            .pickerStyle(.menu)
            .padding()

            List(modelManager.availableModels) { model in
                HStack {
                    Text(model.rawValue)
                    Spacer()
                    if modelManager.downloadedModels.contains(model) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button(action: { modelManager.downloadModel(model) }) {
                            Image(systemName: "icloud.and.arrow.down")
                        }
                    }
                }
            }

            if modelManager.downloadProgress > 0 && modelManager.downloadProgress < 1 {
                ProgressView(value: modelManager.downloadProgress)
            }
        }
        .padding()
    }
}
