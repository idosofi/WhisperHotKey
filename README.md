# WhisperHotkey

A macOS menu bar application that allows you to record audio and transcribe it to text using Whisper.cpp.

## Features

- Record audio from the menu bar.
- Transcribe audio to text using Whisper.cpp.
- Copy the transcript to the clipboard.

## Requirements

- macOS
- Xcode
- Homebrew
- `sox`
- `whisper-cpp`

## Installation

1. Clone the repository.
2. Install the dependencies:
   ```bash
   brew install sox whisper-cpp
   ```
3. Download the Whisper.cpp model:
   ```bash
   ~/.whispercpp/models/download-ggml-model.sh small.en
   ```
4. Open the project in Xcode and run the application.
