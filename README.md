# Narziss

Narziss is a browser extension that adds an AI-powered personal growth navigation layer to AI chat websites.

It now also includes **Narziss Companion**, a native macOS floating voice assistant with a warm, customizable personality, live subtitles, continuous conversation, and a global voice shortcut. It uses an existing ChatGPT-authenticated Codex installation instead of requiring an API key.

It is evolving from a lightweight Socratic tutor into a Human Skill Tree inspired growth system: it maps learning goals, tracks mastery, recommends the next skill, and keeps each exchange concise.

## At a glance

- Works on ChatGPT, DeepSeek, Kimi, Doubao, Tencent Yuanbao, and Qwen Chat
- Captures bounded local chat memory to infer learning gaps
- Fetches and caches the Human Skill Tree GitHub skill catalog as the broad knowledge map
- Uses a Human Skill Tree inspired map to recommend what to learn next when the user is unsure
- Shows a small triangle hint for the knowledge the learner may be missing
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
- Small triangle knowledge-gap hint on the chat page
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

### Narziss Companion for macOS

1. Download `narziss-companion-vX.Y.Z-macos.zip` from the latest GitHub Release.
2. Unzip it and move `Narziss Companion.app` to Applications.
3. Install Codex and sign in with ChatGPT. Narziss automatically uses that Codex subscription session.
4. Open Narziss and allow microphone and speech recognition access when macOS asks.
5. Select the six-point star, or quickly double-tap the right `Option` key. Speak naturally; Narziss shows subtitles only while reading its response, detects turns automatically, and keeps listening until you end the conversation. The shortcut does not require Accessibility access.

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
```

Build a local macOS app bundle with `npm run package:companion`.

Load the `extension/` directory as an unpacked extension during development.

## Release

Create and push a version tag (replace the example with the version in `package.json`):

```bash
git tag v0.11.2
git push origin v0.11.2
```

The GitHub Actions workflow validates and uploads both the browser extension and the macOS Companion release zips.

## License

MIT
