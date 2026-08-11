# Narziss Companion Architecture

Narziss Companion is an independent native macOS client inside the Narziss repository. It does not change the browser extension runtime.

## Version 1 and 2 scope

- Always-on-top floating Narziss orb
- Expandable text chat panel
- Local assistant name, user name, personality, and voice settings
- API key storage in macOS Keychain
- OpenAI Realtime speech-to-speech over WebSocket
- 24 kHz mono PCM microphone capture and audio playback
- Hands-free continuous conversation from the UI or a double-tap of the right `Option` key
- Semantic voice activity detection for automatic turn boundaries
- Response cancellation and conversation truncation when interrupted

## Modules

- `NarzissCompanionCore`: profile, messages, and Realtime event decoding. This target has no UI dependencies and is unit tested.
- `CompanionViewModel`: conversation state machine and coordination between UI, audio, and network layers.
- `RealtimeClient`: ordered Realtime client-event delivery and server-event decoding.
- `AudioIO`: microphone conversion to 24 kHz PCM16 and incremental response playback.
- `CompanionWindowCoordinator`: floating pet panel, chat panel, menu bar item, and global hotkey.

## Security boundary

The OpenAI API key is stored as a generic password in the current user's macOS Keychain with `AfterFirstUnlockThisDeviceOnly` accessibility. Profile fields are stored in UserDefaults. No secrets are packaged into the app or release archive.

## Realtime interaction

The app uses semantic VAD for a hands-free conversation:

1. Start microphone capture once and continuously stream base64 PCM chunks.
2. Let semantic VAD detect speech start and stop events.
3. Automatically create a response when the user finishes a turn.
4. Stop local playback and truncate unplayed audio when the user interrupts.
5. Play `response.output_audio.delta` chunks and render both transcripts as chat messages.
