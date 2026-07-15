# Narziss

Narziss is a browser extension for adaptive learning and GitHub project explanations inside AI chat websites.

It adds a lightweight learning layer to the chat tools people already use: it teaches one atomic concept at a time, tracks a small local knowledge map, and can switch into a repository-explanation workflow when a public GitHub URL appears in the conversation.

## At a glance

- Works on ChatGPT, DeepSeek, Kimi, Doubao, Tencent Yuanbao, and Qwen Chat
- Teaches in small steps and adapts when the learner says they are stuck
- Explains public GitHub repositories with evidence from repository metadata and source files
- Keeps learning state local to the browser
- Leaves the underlying AI chat experience unchanged when switched off

## How it works

When Narziss is on, it wraps the outgoing message with a structured learning prompt before sending it through the current AI chat website. The extension keeps a lightweight local session with the current knowledge node and mastery level, while the model is instructed to return only learner-facing content.

For GitHub repository links, Narziss collects a bounded evidence package: repository metadata, README, language usage, directory tree, and selected entry files. It then explains the project through a dedicated flow rather than the normal learning path.

## Capabilities

- ON / OFF control from the extension popup
- Automatic recognition of public GitHub repository links
- A private seven-step learning pipeline: intent, map, path, teaching, checking, consolidation, and reinforcement
- One minimal definition followed by one concrete question on the first turn
- Adaptive depth when a learner says “I don't know” or “不清楚”
- A confirmation step before moving past 90% node mastery
- Manual injection into the active AI chat tab
- Local session continuity for each chat page

## Important limitation

Narziss uses prompt injection in the webpage input box. It does not control the model at the system level and does not use a private API proxy. It can strongly guide model behavior, but cannot guarantee that every model will always follow the prompt.

## Install

### From a GitHub Release

1. Download `narziss-extension-vX.Y.Z.zip` from the latest GitHub Release.
2. Unzip the file.
3. Open `chrome://extensions` or `edge://extensions`.
4. Enable Developer mode.
5. Click “Load unpacked”.
6. Select the unzipped `extension/` folder.

### From source

No build step is required for the extension itself.

1. Clone this repository.
2. Open `chrome://extensions` or `edge://extensions`.
3. Enable Developer mode and click “Load unpacked”.
4. Select the `extension/` directory.

## Use

1. Open a supported AI chat website.
2. Click the Narziss extension icon and turn it on.
3. Type what you want to learn in the chat page.
4. To understand a GitHub project, paste a public repository URL into the chat box and send it.

When Narziss is off, your message is not changed.

## Development

```bash
npm test
```

Load the `extension/` directory as an unpacked extension during development.

## Release

Create and push a version tag:

```bash
git tag v0.7.4
git push origin v0.7.4
```

The GitHub Actions workflow validates the extension and uploads a release zip.

## License

MIT
