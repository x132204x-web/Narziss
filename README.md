# Narziss

Narziss is an open-source browser extension that adds adaptive learning and GitHub project explanations to AI chat websites.

When Narziss is on, your message is wrapped in a strict learning prompt before it is sent. Narziss builds a small knowledge map, teaches one atomic node at a time, and keeps each exchange concise.

## What it does

- Adds a Narziss ON/OFF switch.
- Automatically recognizes public GitHub repository links and switches to a dedicated project explanation flow.
- Reads repository metadata, README, language usage, directory tree, and selected entry files before asking the model to explain.
- Produces an evidence-based overview, analogy, architecture flow, key-file guide, setup path, strengths, and limitations.
- Follows a private seven-step learning pipeline: intent, map, path, teaching, checking, consolidation, and reinforcement.
- Saves a lightweight learning session for each chat page, including the current knowledge node and mastery.
- Automatically adapts to the learner's depth, including when the user says "I don't know" or "不清楚".
- Uses a lightweight first turn: one minimal definition, then one concrete question.
- At 90% node mastery, asks before moving to the next knowledge node.
- Keeps knowledge maps, mastery scores, and control metadata out of the learner-facing conversation.
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

When Narziss is on, the extension replaces your outgoing message with a structured Narziss prompt. The extension keeps a lightweight local learning state for continuity, while the model is instructed to output only the learner-facing response. When Narziss is off, your message is not changed.

To understand a GitHub project, paste a public repository URL such as `https://github.com/owner/repository` into the chat box and send it. Narziss detects the link, collects a bounded repository evidence package, and uses the project explanation flow instead of the normal learning flow.

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
git tag v0.7.4
git push origin v0.7.4
```

The GitHub Actions workflow validates the extension and uploads a release zip.

## License

MIT
