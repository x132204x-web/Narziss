# Installation

Narziss is distributed as source code and a GitHub Release zip.

## Narziss Companion for macOS

Requirements:

- macOS 14 or later
- Codex installed and signed in with ChatGPT
- Microphone and Speech Recognition permission

Install:

1. Download `narziss-companion-vX.Y.Z-macos.zip` from GitHub Releases.
2. Unzip the archive and move `Narziss Companion.app` to `/Applications`.
3. Open the app. If macOS warns about an unsigned download, Control-click the app and choose Open.
4. Make sure the Codex app or CLI is already signed in with ChatGPT.
5. Select the floating six-point star to start listening. Narziss finds the local Codex installation and connects automatically.
6. Choose names and personality in Settings if desired.

Select the six-point star or quickly double-tap the right `Option` key to begin a continuous conversation. The shortcut does not require Accessibility permission. Narziss sends each spoken turn through the signed-in Codex subscription, shows subtitles while reading its response with a macOS system voice, and then resumes listening. Use the same control again to end the voice session.

By default, Narziss chooses from 100 curated work memes, skips low-resolution source images, shows one beside the floating star every 20 minutes, and hides it after 12 seconds. Use the menu bar to show one immediately or disable the reminders. Only the selected image is loaded from ChineseBQB and cached locally; the full repository is never downloaded.

No OpenAI API key is requested or stored by Narziss. Profile settings are stored locally in UserDefaults.

## Chrome or Edge

1. Download the latest `narziss-extension-vX.Y.Z.zip` from GitHub Releases.
2. Unzip it.
3. Open `chrome://extensions` or `edge://extensions`.
4. Enable Developer mode.
5. Click "Load unpacked".
6. Select the unzipped `extension` folder.

## Update

1. Download the newer release zip.
2. Unzip it over a new local folder.
3. Open the browser extension management page.
4. Remove the old unpacked Narziss extension.
5. Load the new `extension` folder.

## Supported sites

- `https://chatgpt.com/*`
- `https://chat.openai.com/*`
- `https://chat.deepseek.com/*`
- `https://deepseek.com/*`
- `https://kimi.com/*`
- `https://www.kimi.com/*`
- `https://kimi.moonshot.cn/*`
- `https://doubao.com/*`
- `https://www.doubao.com/*`
- `https://yuanbao.tencent.com/*`
- `https://chat.qwen.ai/*`

For other AI chat websites, open the site, click the Narziss extension icon, and turn Narziss on. The popup will try to inject Narziss into the current tab with the browser's `activeTab` permission.
