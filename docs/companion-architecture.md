# Narziss Companion Architecture

Narziss Companion is an independent native macOS client inside the Narziss repository. It does not change the browser extension runtime.

## Companion scope

- Always-on-top floating Narziss orb
- Lightweight bottom subtitle overlay instead of a chat panel
- A lightweight work-meme bubble beside the floating star every 20 minutes
- Local assistant name, user name, and personality settings
- ChatGPT subscription authentication inherited through the official Codex App Server
- macOS Speech recognition and AVSpeechSynthesizer output
- Hands-free continuous conversation from the UI or a double-tap of the right `Option` key
- Silence-based automatic turn boundaries
- Response cancellation from the UI or global shortcut

## Modules

- `NarzissCompanionCore`: profile, messages, shortcut timing, Codex event decoding, and microphone format normalization. This target has no UI dependencies and is unit tested.
- `CompanionViewModel`: conversation state machine and coordination between UI, audio, and network layers.
- `CodexAppServerClient`: starts the official local `codex app-server`, performs the JSON-RPC handshake, and streams Codex text events.
- `SystemSpeechIO`: macOS speech recognition, mono 16 kHz input normalization, silence turn detection, and system speech synthesis.
- `CompanionWindowCoordinator`: floating six-point-star panel, subtitle panel, settings panel, menu bar item, and global hotkey.
- `MemeReminderController`: reminder timing, non-repeating meme rotation, remote image caching, and automatic dismissal.

## Security boundary

Narziss does not read, copy, or store ChatGPT tokens. The official Codex process owns authentication and inherits the user's existing Codex login. The Codex thread uses a read-only sandbox, an approval policy of `never`, and explicit instructions not to execute tools. Profile fields are stored in UserDefaults. No secrets are packaged into the app or release archive.

## Conversation interaction

The app uses local operating-system speech services around a Codex text thread:

1. Start macOS speech recognition without displaying the user's partial transcription.
2. Treat a stable transcript followed by silence as the end of the user's turn.
3. Send the transcript to an ephemeral Codex App Server thread using the existing ChatGPT login.
4. Read the completed answer with `AVSpeechSynthesizer` while showing it in the subtitle overlay.
5. Clear the subtitle, then resume listening.
