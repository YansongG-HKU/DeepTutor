# Chat

Chat lets a learner type a prompt on Home and read the tutor's reply in the same conversation.

## Sub-features

- `chat-open` opens Home and focuses the composer.
- `chat-send` sends the typed prompt.
- `chat-reply` shows a completed tutor reply rather than an error alert.

## How to get to it (user POV)

- Choose `Home` in the sidebar.
- Open `/chat` on the frontend origin. `/` redirects there.

## Driving it with verify-deeptutor

Preconditions:

- Doctor reports the verification frontend, the disposable home, disabled auth, and English.
- `GET /api/system/status` reports `llm.status` as `configured`. A fresh verification home does not meet this precondition.

- **Read model status.** The script requests `$BACKEND_URL/api/system/status` and writes `system-status.json`. When `llm.status` is not `configured`, it still opens Home, writes `blocked.png` and `blocked.aria.txt`, and exits with `"pass": false`. It does not send the prompt and it does not substitute a provider.
- **Open Home.** Choose `Home`. `scripts/drive.mjs chat` clicks the link named `Home`. The textbox named `How can I help you today?` is visible and the document title is `DeepTutor`.
- **Enter a prompt.** Type `Reply with the single word ready.` The script fills that textbox and writes `draft.png` and `draft.aria.txt`. The button named `Send` is enabled.
- **Send.** Choose `Send`. The script clicks the button named `Send`.
- **Read the reply.** An element with `data-chat-message-role="assistant"` is visible, the `Send` button is back, and that assistant element contains text and no alert. The script writes `reply.png` and `reply.aria.txt`. An alert inside the assistant message fails the journey. The script writes `failed.png` when that happens.

The command for this whole journey is:

```bash
.cursor/skills/verify-deeptutor/scripts/drive.mjs chat
```

`result.json` has `"pass": true` only when a configured model produced an assistant message with text and no alert.

## Gotchas

- With authentication off, Home stays available to the local admin even when no model is configured. Opening Home is not a successful chat.
- `Send` is disabled while the composer is empty. Its accessible name is `Stop generating` while a reply is streaming and `Send answer` while a question is waiting.
- A turn that fails shows an alert on the assistant message, including `No response was generated. Please try again.` That alert is a failure.
- Do not mock `/api` or point the app at a fake model to obtain a reply. Configure a real provider in Settings, then run this journey again.
- The CLI entry `deeptutor run chat "..."` is a different surface. This file does not treat CLI output as a web chat proof.
