# Narziss

Narziss is an open-source browser extension that adds an automatic Socratic learning mode to AI chat websites.

When Narziss is on, your message is wrapped in a strict learning prompt before it is sent. The model is pushed to ask one thinking question at a time instead of explaining everything immediately.

## What it does

- Adds a Narziss ON/OFF switch.
- Supports four learning phases:
  - Activation
  - Construction
  - Disruption
  - Synthesis
- Automatically asks the model to infer the learning topic and phase from the user's message.
- Uses a lightweight first turn: one minimal definition, then one concrete question.
- Keeps AI chat websites usable normally when Narziss is off.
- Auto-runs on ChatGPT, DeepSeek, Kimi, Doubao, Tencent Yuanbao, and Qwen Chat.
- Can be manually injected into the current AI chat tab from the popup.
- Ships as a browser extension that can be loaded in Chrome or Edge.

## Important limitation

Narziss uses prompt injection in the webpage input box. It does not control the model at the system level, and it does not use a private API proxy. This means it can strongly guide model behavior, but it cannot absolutely guarantee that a model will always obey.

## Install from GitHub Release

1. Download `narziss-extension-vX.Y.Z.zip` from the latest GitHub Release.
2. Unzip the file.
3. Open `chrome://extensions` or `edge://extensions`.
4. Enable Developer mode.
5. Click "Load unpacked".
6. Select the unzipped `extension` folder.

## Use

1. Open an AI chat website in the browser.
2. Click the Narziss extension icon.
3. Turn Narziss on.
4. Type what you want to learn in the chat page.

When Narziss is on, the extension replaces your outgoing message with a structured Narziss prompt. The prompt tells the model to infer the topic and learning phase automatically. When it is off, your message is not changed.

## Development

No build step is required for the extension itself.

Run the local validation script:

```bash
npm test
```

Load the `extension/` directory as an unpacked extension during development.

## Release

Create a version tag such as:

```bash
git tag v0.3.0
git push origin v0.3.0
```

The GitHub Actions workflow validates the extension and uploads a release zip.

## License

MIT
