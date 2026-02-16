# Screen Assistant

A native macOS application that captures your screen, analyzes it with AI, and displays the answer in an overlay window that is **invisible to screen recorders**.

## Features

- **Invisible Overlay**: The result window uses `NSWindow.sharingType = .none`, making it invisible to Zoom, OBS, QuickTime, and screenshots.
- **AI Analysis**: Captures the screen content and asks **Google Gemini** to analyze it.
- **Markdown Support**: The overlay renders rich text, including lists and bold text.
- **Interactive Crop**: Use the crosshair to select exactly what you want to analyze.
- **Scrollable & Interactive**: The overlay supports scrolling for long answers.
- **Global Hotkey**: Press **Cmd + Option + S** to trigger a crop and analyze.
- **Toggle Visibility**: Press **Cmd + Option + H** to hide/show the overlay.
- **Quit Hotkey**: Press **Cmd + Option + Q** to quit.

## Setup

1.  **Build the app**:
    ```bash
    swift build -c release
    ```

2.  **Set your Google Gemini API Key**:
    The app uses Google's Gemini API. Get a key from [Google AI Studio](https://aistudio.google.com/).
    ```bash
    export GEMINI_API_KEY="AIza..."
    ```
    Or create a `.env` file in the project directory:
    ```bash
    echo 'GEMINI_API_KEY="AIza..."' > .env
    ```

3.  **Run the app**:
    ```bash
    ./.build/release/ScreenAssistant
    # OR use the helper script
    ./run.sh
    ```

## Usage

1.  Launch the app. You'll see an "eye" icon in the menu bar.
2.  **Grant Permissions**: The first time you run it, macOS might ask for "Screen Recording" permissions. Open `System Settings > Privacy & Security > Screen Recording` and enable `ScreenAssistant` (or `Terminal` if running from there).
3.  **Trigger**: Press **Cmd + Option + S**.
4.  **View Result**: An overlay window will appear with the answer.
    *   **Important**: If you see "Permission Missing" or the AI describes your wallpaper, enable **Screen Recording** for your Terminal app in System Settings.

## Troubleshooting

- **No overlay appears?**
  - Check if `Screen Recording` permission is enabled.
  - Check the terminal output for errors.
- **API Error?**
  - Ensure `GEMINI_API_KEY` is set correctly.
