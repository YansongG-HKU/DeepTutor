# Knowledge bases

Knowledge bases lets a learner create a named knowledge base from Knowledge Center and see it in the library after a reload.

## Sub-features

- `knowledge-open` opens Knowledge Center.
- `knowledge-create-dialog` opens the create dialog and accepts a name.
- `knowledge-create` saves the knowledge base when the selected engine can run.
- `knowledge-persist` lists that knowledge base after reload.

## How to get to it (user POV)

- Choose `Learning Space` in the sidebar, then choose `Knowledge Center`.
- Open `/knowledge-bases` on the frontend origin.

## Driving it with verify-deeptutor

Preconditions:

- Doctor reports the verification frontend, the disposable home, disabled auth, and English.
- `GET /api/system/status` reports `embeddings.status` as `configured`. A fresh verification home does not meet this precondition. The dialog opens on the LlamaIndex engine, which needs an embedding model.
- No knowledge base is named `verification-library`.

- **Read embedding status.** The script requests `$BACKEND_URL/api/system/status` and writes `system-status.json`.
- **Open Knowledge Center.** Choose `Learning Space`, then `Knowledge Center`. `scripts/drive.mjs knowledge` clicks those links. The heading `Knowledge Center` is visible.
- **Open the dialog.** Choose `New knowledge base`. The script clicks the button named `New knowledge base`. A dialog named `Create knowledge base` is visible.
- **Enter a name.** Type `verification-library` into the field whose placeholder is `e.g. project-papers`. The script writes `dialog.png` and `dialog.aria.txt`.
- **Create when embeddings exist.** When `embeddings.status` is `configured`, the script clicks `Create` inside the dialog. A heading `verification-library` is visible. After reload the text `verification-library` is still visible, and the script writes `saved.png` and `saved.aria.txt`.
- **Stop when embeddings are missing.** When `embeddings.status` is not `configured`, `Create` is disabled. The script records `"pass": false` and the status value. It does not change the engine, does not click `Create`, and does not invent an embedding endpoint.

The command for this whole journey is:

```bash
.cursor/skills/verify-deeptutor/scripts/drive.mjs knowledge
```

`result.json` has `"pass": true` only when the named knowledge base was created and is still visible after reload.

## Gotchas

- The name field has a visible label `Knowledge base name` that is not tied to the input. The stable handle is the placeholder `e.g. project-papers`.
- Names cannot contain characters the product rejects as path or URL separators. `verification-library` is a legal name.
- LlamaIndex, LightRAG, and GraphRAG keep `Create` disabled until their model requirements are satisfied. Switching to another engine to avoid that requirement is a different journey and does not pass this one.
- A disabled `Create` button with `embeddings.status` of `not_configured` is the expected failure on a fresh home. Do not report the open dialog as a created knowledge base.
