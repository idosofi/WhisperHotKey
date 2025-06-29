import SwiftUI

struct SettingsView: View {
    @StateObject private var modelManager = ModelManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text("Model Management")
                .font(.title)

            Picker("Selected Model", selection: $modelManager.selectedModel) {
                ForEach(modelManager.availableModels) { modelInfo in
                    Text("\(modelInfo.type.rawValue) \(modelInfo.fileSize ?? "")")
                        .tag(modelInfo.type)
                }
            }
            .pickerStyle(.menu)
            .padding()

            List(modelManager.availableModels) { modelInfo in
                HStack {
                    Text("\(modelInfo.type.rawValue) \(modelInfo.fileSize ?? "")")
                    Spacer()
                    if modelInfo.isDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Button(action: { modelManager.deleteModel(modelInfo.type) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(modelManager.selectedModel == modelInfo.type)
                    } else if modelManager.downloadingModel == modelInfo.type {
                        ProgressView(value: modelManager.downloadProgress)
                            .frame(width: 50, height: 20) // Adjust size as needed
                        Text("\(Int(modelManager.downloadProgress * 100))%")
                    } else {
                        Button(action: { modelManager.downloadModel(modelInfo) }) {
                            Image(systemName: "icloud.and.arrow.down")
                        }
                    }
                }
            }

            Button("Done") {
                dismiss()
            }
            .disabled(!modelManager.modelIsDownloaded(modelManager.selectedModel))
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300) // Set minimum size for the window
    }
}
