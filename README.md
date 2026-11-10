# Narziss

Narziss is a browser extension that adds an AI-powered personal growth navigation layer to AI chat websites.

It now also includes **Narziss Companion**, a native macOS floating voice assistant with a warm, customizable personality, live subtitles, continuous conversation, and a global voice shortcut. It uses an existing ChatGPT-authenticated Codex installation instead of requiring an API key.

It is evolving from a lightweight Socratic tutor into a Human Skill Tree inspired growth system: it maps learning goals, tracks mastery, recommends the next skill, and keeps each exchange concise.

## At a glance

- Works on ChatGPT, DeepSeek, Kimi, Doubao, Tencent Yuanbao, and Qwen Chat
- Captures bounded local chat memory to infer learning gaps
- Fetches and caches the Human Skill Tree GitHub skill catalog as the broad knowledge map
- Uses a Human Skill Tree inspired map to recommend what to learn next when the user is unsure
- Shows a small triangle floating window for the knowledge the learner may be missing
- Teaches in small steps and adapts when the learner says they are stuck
- Explains public GitHub repositories with evidence from repository metadata and source files
- Keeps learning state local to the browser
- Leaves the underlying AI chat experience unchanged when switched off

## How it works

When Narziss is on, it wraps the outgoing message with a structured learning prompt before sending it through the current AI chat website. The extension keeps a lightweight local session with the current knowledge node and mastery level, while the model is instructed to return only learner-facing content.

When the user asks "我不知道学什么", "下一步该学什么", or "帮我补齐短板", Narziss switches into growth navigation mode. It uses bounded local chat memory, the Human Skill Tree reference map, the GitHub skill catalog, and a goal-specific skill tree to recommend the next learning node.

For GitHub repository links, Narziss collects a bounded evidence package: repository metadata, README, language usage, directory tree, and selected entry files. It then explains the project through a dedicated flow rather than the normal learning path.

See [docs/product-architecture.md](docs/product-architecture.md) for the Human Skill Tree inspired product direction.

## Capabilities

- ON / OFF control from the extension popup
- Small triangle knowledge-gap floating window on the chat page
- Two-finger press or right-click on the triangle opens lightweight settings
- Bounded local capture of recent visible chat context
- GitHub skill catalog fetch and 24-hour local cache
- Growth recommendation mode for "what should I learn next?"
- Automatic recognition of public GitHub repository links
- A private seven-step learning pipeline: intent, map, path, teaching, checking, consolidation, and reinforcement
- One minimal definition followed by one concrete question on the first turn
- Adaptive depth when a learner says "I don't know" or "不清楚"
- A confirmation step before moving past 90% node mastery
- Manual injection into the active AI chat tab
- Local session continuity for each chat page

## Important limitation

Narziss uses prompt injection in the webpage input box. It does not control the model at the system level and does not use a private API proxy. It can strongly guide model behavior, but cannot guarantee that every model will always follow the prompt.

## Install

### Narziss Notch for macOS

A separate, native macOS 14+ utility inspired by the notch interaction in [Atoll](https://github.com/Ebullioscopic/Atoll). Written independently; no Atoll code or assets are bundled.

1. Download `narziss-notch-vX.Y.Z-macos.zip` from GitHub Releases, unzip, and move **Narziss Notch.app** to Applications.
2. Open the app. Hover at the top-center notch to expand it; move away to collapse. Optionally pin it to keep it open. It disappears completely when the cursor leaves: no clock, media label, or extra bar remains. Click the top bar, use the fold button, or press Escape to fold it manually.
3. Use the **Clock**, **Calendar**, **Clipboard**, and **Media** tabs.

- **Clock:** live local time and a countdown timer with 5/15/25-minute presets, typed hours (0–99) and minutes (0–59), with an hours:minutes:seconds display for longer countdowns, pause/resume, and a completion notification with sound. Starting your first timer asks for notification permission. When time is up, the notch opens to the Clock tab and stays open until folded, even if macOS notifications are disabled. The timer continues while folded or switching tabs; folding hides all content while the timer keeps running.
- **Calendar:** a month grid and selected-day events from macOS Calendar. Opening Calendar requests access once if needed, then automatically reuses the macOS grant on later visits and relaunches. Calendar data is read only by this app.
- **Clipboard:** enable Capture to collect up to 60 recent text copies; search, click to copy, star, delete, or clear recent clips.  **recent history is memory-only and clears when the app quits**. Capture starts with the next copy, and pausing does not erase existing history. Entries marked concealed/transient by their source app are skipped; apps that do not mark sensitive text can still have that text captured. Images and files are not captured. Click the **star** on a recent clip to keep frequently used information permanently. Find it in **Starred**, where you can copy, edit, delete, or add clips. Starred clips are stored locally in `~/Library/Application Support/Narziss Notch/snippets.json`, survive relaunch, and are unaffected by clearing recent history. Back up this file to protect against disk loss.
- **Media:** automatically connects on every launch to show the Mac’s active Now Playing session, including browser videos, podcasts, Music, and Spotify. Play/pause/previous/next act on the active system session; available commands depend on the source. Sites and apps that do not publish macOS Now Playing information cannot be detected. The bundled BSD-licensed [MediaRemote adapter](macos/NarzissNotch/Vendor/NOTICE.md) uses a private macOS framework; future OS changes may require updates.

The app uses the built-in notched display when available and otherwise sits at the top center of the main display. The menu bar offers Show / Hide, Keep Open, and Quit. No account, server, or API key is needed. The current build is ad-hoc signed rather than Developer ID signed/notarized, so macOS may require approval in Privacy & Security on first launch. macOS can also request Calendar permission again after installing a new ad-hoc signed build. Preserving app identity across releases requires a Developer ID certificate; none is configured in this repository’s release workflow.

Build locally with `npm run package:notch`, then open `dist/Narziss Notch.app`. Run `npm run test:notch` for clipboard, countdown, saved-library, and calendar tests. For UI inspection with sample recent clips and media (starred clips use a temporary directory), launch with `open "dist/Narziss Notch.app" --args --preview --tab Clipboard` (also accepts Clock, Calendar, or Media); quit the app before switching launch modes.

### Narziss Companion for macOS

1. Download `narziss-companion-vX.Y.Z-macos.zip` from the latest GitHub Release.
2. Unzip it and move `Narziss Companion.app` to Applications.
3. Install Codex and sign in with ChatGPT. Narziss automatically uses that Codex subscription session.
4. Open Narziss and allow microphone and speech recognition access when macOS asks.
5. Select the six-point star, or quickly double-tap the right `Option` key. Speak naturally; Narziss shows subtitles only while reading its response, detects turns automatically, and keeps listening until you end the conversation. Two-finger click the floating star to open settings or quit Narziss. These controls do not require Accessibility access.

While Narziss is running, it can choose from 100 office-safe work memes and show one beside the floating star every 20 minutes. Double-click the image to replace it immediately. Low-resolution source images are skipped automatically before display. The menu bar offers “show one now” and an on/off toggle. Curated images are loaded on demand from [ChineseBQB](https://github.com/zhaoolee/ChineseBQB) and cached by macOS; the full collection is not bundled or downloaded.

Narziss launches the official local `codex app-server` and follows the Codex usage limits of the signed-in ChatGPT account. Speech recognition and speech output use macOS system frameworks, so no separate OpenAI API configuration is required.

### From a GitHub Release

1. Download `narziss-extension-vX.Y.Z.zip` from the latest GitHub Release.
2. Unzip the file.
3. Open `chrome://extensions` or `edge://extensions`.
4. Enable Developer mode.
5. Click "Load unpacked".
6. Select the unzipped `extension/` folder.

### From source

No build step is required for the extension itself.

1. Clone this repository.
2. Open `chrome://extensions` or `edge://extensions`.
3. Enable Developer mode and click "Load unpacked".
4. Select the `extension/` directory.

## Use

1. Open a supported AI chat website.
2. Click the Narziss extension icon and turn it on.
3. Type what you want to learn, ask what to learn next, or paste a public GitHub repository URL.

When Narziss is off, your message is not changed.

## Development

```bash
npm test
npm run test:companion
npm run test:notch
```

Build a local macOS app bundle with `npm run package:companion`.

Load the `extension/` directory as an unpacked extension during development.

## Release

Create and push a version tag (replace the example with the version in `package.json`):

```bash
git tag v0.12.4
git push origin v0.12.4
```

The GitHub Actions workflow validates and uploads the browser extension, macOS Companion, and macOS Notch release zips.

## License

MIT
