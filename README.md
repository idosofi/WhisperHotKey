# WhisperHotkey

## Overview

WhisperHotkey is a macOS application that leverages the power of OpenAI's Whisper model to provide instant, hotkey-triggered speech-to-text transcription. Designed for efficiency, it allows users to quickly transcribe spoken words into text, making it ideal for note-taking, dictation, or capturing thoughts on the fly.

## Features

*   **Hotkey Activation:** Trigger transcription instantly with a customizable global hotkey.
*   **Local Model Processing:** All transcription is performed locally on your device, ensuring privacy and offline functionality.
*   **Model Management:** Easily download, select, and manage different Whisper models (e.g., tiny, base, small, medium, large) directly within the application settings.
*   **Download Progress Indicator:** Visual feedback during model downloads, showing progress and status.
*   **Lightweight and Efficient:** Built with Swift and SwiftUI for a native macOS experience.

## Installation

To install and run WhisperHotkey, you'll need Xcode installed on your macOS machine.

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/WhisperHotkey.git
    cd WhisperHotkey
    ```
2.  **Open in Xcode:**
    Open the `WhisperHotkey.xcodeproj` file in Xcode.
3.  **Resolve Swift Packages:**
    Xcode should automatically resolve the Swift Package dependencies (e.g., `WhisperFramework`). If not, go to `File > Packages > Resolve Package Versions`.
4.  **Build and Run:**
    Select the `WhisperHotkey` scheme and your target (e.g., "My Mac" or a macOS simulator) and click the Run button (▶️) in Xcode.

## Usage

1.  **Launch the Application:** After building and running from Xcode, the WhisperHotkey icon will appear in your menu bar.
2.  **Configure Settings:**
    *   Click the menu bar icon and select "Settings...".
    *   In the "Model Management" section, you can see available Whisper models.
    *   **Download Models:** Click the cloud icon (☁️) next to a model to download it. A progress indicator will show the download status.
    *   **Select Model:** Choose your preferred model from the "Selected Model" picker.
    *   **Delete Models:** Click the trash can icon (🗑️) to remove a downloaded model.
    *   Click "Done" to save your settings.
3.  **Start Transcribing:**
    *   Press the global hotkey (default: **[To be determined/configured in app]**).
    *   Speak clearly into your microphone.
    *   Press the hotkey again to stop recording.
    *   The transcribed text will appear in the application's main window.

## Model Management Details

WhisperHotkey allows you to manage different sizes of Whisper models. Larger models generally offer higher accuracy but require more disk space and computational resources.

*   **`ggml-tiny.en.bin`**: Smallest, fastest, least accurate (English only).
*   **`ggml-base.en.bin`**: Balanced performance (English only).
*   **`ggml-small.en.bin`**: Good balance of speed and accuracy (English only).
*   **`ggml-medium.en.bin`**: Higher accuracy, slower (English only).
*   **`ggml-large-v1.bin`**, **`ggml-large-v2.bin`**, **`ggml-large-v3.bin`**: Largest, most accurate, slowest (multilingual).

Models are downloaded from Hugging Face and stored locally in `~/Documents/whisper_models/`.

## Contributing

We welcome contributions to WhisperHotkey! If you'd like to contribute, please follow these steps:

1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/your-feature-name`).
3.  Make your changes.
4.  Commit your changes (`git commit -m 'Add some feature'`).
5.  Push to the branch (`git push origin feature/your-feature-name`).
6.  Open a Pull Request.

Please ensure your code adheres to the existing Swift style and conventions used in the project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## Acknowledgements

*   [OpenAI Whisper](https://openai.com/research/whisper)
*   [ggerganov/whisper.cpp](https://github.com/ggerganov/whisper.cpp)
*   [Hugging Face](https://huggingface.co/) for hosting the models.