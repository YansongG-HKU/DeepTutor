# Notebooks

Notebooks lets a learner create a named notebook from Learning Space and see that notebook, with its description, after a reload.

## Sub-features

- `notebooks-open` opens the notebook list from Learning Space.
- `notebooks-create` saves a name and description from the new-notebook form.
- `notebooks-persist` shows the same notebook after reload.
- `notebooks-cli-show` returns that notebook from `deeptutor notebook show`.

## How to get to it (user POV)

- Choose `Learning Space` in the sidebar, then choose the `Notebooks` card.
- Open `/notebooks` on the frontend origin.
- Run `deeptutor notebook create "Verification notebook" --description "Created from the browser"` in a terminal whose `DEEPTUTOR_HOME` is the verification home. That command is a separate entry point. Showing a notebook the browser already created does not verify it.

## Driving it with verify-deeptutor

Preconditions:

- Doctor reports the verification frontend, the disposable home, disabled auth, and English.
- The home has no notebook named `Verification notebook`.

- **Open Learning Space.** Choose `Learning Space`. `scripts/drive.mjs notebooks` clicks the link named `Learning Space`. The heading `Learning Space` is visible.
- **Open notebooks.** Choose `Notebooks`. The script clicks the link named `Notebooks`. The heading `Notebooks` and the button `New notebook` are visible.
- **Open the form.** Choose `New notebook`. The script clicks the button named `New notebook`. Text fields with placeholders `Notebook name` and `Description (optional)` are visible.
- **Enter the notebook.** Type the name and description. The script fills those placeholders with `Verification notebook` and `Created from the browser`. The `Create` button is enabled. The script writes `draft.png` and `draft.aria.txt`.
- **Create.** Choose `Create`. The script clicks the button named `Create`. A level-2 heading reads `Verification notebook` and a paragraph reads `Created from the browser`. The same description is also in the list button, so the script asserts the paragraph rather than every text node. The address ends in `/notebooks/<id>`.
- **Reload.** Reload the notebook page. The same heading and paragraph are visible, and a button whose name starts with `Verification notebook` is visible. The script writes `saved.png` and `saved.aria.txt`.
- **CLI read-back.** In the verification home, run `deeptutor notebook show <id> --format json`. The script runs that command with `DEEPTUTOR_HOME` set and records stdout, stderr, and the exit code. Exit code is `0`. The JSON `name` is `Verification notebook` and `description` is `Created from the browser`.
- **Stored file.** The notebook JSON file under the home contains the same name. The script copies it to `notebook.json`.

The command for this whole journey is:

```bash
.cursor/skills/verify-deeptutor/scripts/drive.mjs notebooks
```

`result.json` has `"pass": true` only when the reloaded page, the CLI JSON, and the stored file all match.

## Gotchas

- The create fields use placeholders, not accessible names. The edit form, which is not part of this journey, does label `Notebook name`.
- The list button's accessible name includes the record count, for example `Verification notebook 0`. Match the name as a prefix, not as the whole string.
- The description is rendered twice, once in that button and once in a paragraph under the heading. A text query for the description alone is ambiguous.
- `Create` submits the open form. Do not press it before the name is filled; the button stays disabled for an empty name.
- `deeptutor notebook list` prints a table and has no JSON format. Use `notebook show <id> --format json` for the assertion.
- CLI create is a different entry point. A passing browser journey does not verify `deeptutor notebook create`.
- The notebook file lives in the disposable home. Cleanup deletes that home and keeps `artifacts/<run-id>/notebooks/`.
- An `Update available` link can appear in the sidebar when the release check finds a newer version. It does not block this journey.
