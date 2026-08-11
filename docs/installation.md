# Installation

Narziss is distributed as source code and a GitHub Release zip.

## Narziss Companion for macOS

Requirements:

- macOS 14 or later
- An OpenAI API key with Realtime API access
- Microphone permission

Install:

1. Download `narziss-companion-vX.Y.Z-macos.zip` from GitHub Releases.
2. Unzip the archive and move `Narziss Companion.app` to `/Applications`.
3. Open the app. If macOS warns about an unsigned download, Control-click the app and choose Open.
4. Select the floating orb to open chat, then open Settings.
5. Choose names, personality, and voice, enter the API key, and select Save and Connect.

Use Start Voice Conversation or quickly double-tap the right `Option` key to begin a continuous conversation. Grant Accessibility permission when macOS asks so the shortcut works while other apps are active. Narziss automatically detects when you start and finish each turn, responds, and keeps listening. Speak while Narziss is responding to interrupt naturally. Use the same button or shortcut again to end the voice session.

The API key is stored only in macOS Keychain. The app never writes it into this repository or UserDefaults.

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
