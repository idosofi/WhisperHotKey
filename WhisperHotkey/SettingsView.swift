
import SwiftUI

struct SettingsView: View {
    @StateObject var modelManager = ModelManager.shared

    var body: some View {
        Form {
            Section(header: Text("Whisper Models")) {
                Picker("Selected Model", selection: $modelManager.selectedModelId) {
                    ForEach(modelManager.availableModels) { model in
                        Text("\(model.name) (\(model.size))")
                            .tag(model.id as String?)
                    }
                }
                .pickerStyle(.inline)

                ForEach(modelManager.availableModels) { model in
                    HStack {
                        Text(model.name)
                        Spacer()
                        if modelManager.isDownloading[model.id, default: false] {
                            ProgressView(value: modelManager.downloadProgress[model.id, default: 0.0])
                                .progressViewStyle(.linear)
                                .frame(width: 100)
                        } else if modelManager.downloadedModels[model.id, default: false] {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Button("Download") {
                                modelManager.downloadModel(model)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Settings")
    }
}
