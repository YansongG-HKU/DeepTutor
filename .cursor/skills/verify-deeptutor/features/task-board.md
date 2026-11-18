# Task board

Task board lets a learner add a task and find that task in the To do column after a reload.

## Sub-features

- `task-open` opens the task board.
- `task-add` adds a titled task to To do.
- `task-persist` shows the same task in To do after reload and stores it in the board database.

## How to get to it (user POV)

- Choose `Task Board` in the sidebar.
- Open `/kanban` on the frontend origin.

## Driving it with verify-deeptutor

Preconditions:

- Doctor reports the verification frontend, the disposable home, disabled auth, and English.
- No card is titled `Verify the task board`.

- **Open the board.** Choose `Task Board`. `scripts/drive.mjs task-board` clicks the link named `Task Board`. The heading `Task Board` and the textbox named `New task` are visible.
- **Enter a title.** Type `Verify the task board` into `New task`. The script fills that textbox. The `Add` button is enabled. The script writes `draft.png` and `draft.aria.txt`.
- **Add the task.** Choose `Add`. The script clicks the button named `Add`. The region named `To do` contains the text `Verify the task board`.
- **Reload.** Reload the board. The same region still contains `Verify the task board`. The script writes `saved.png` and `saved.aria.txt`.
- **Stored row.** The home's `task-board/tasks.sqlite` database has a `cards` row whose title is `Verify the task board` and whose status is `todo`.

The command for this whole journey is:

```bash
.cursor/skills/verify-deeptutor/scripts/drive.mjs task-board
```

`result.json` has `"pass": true` only when the reloaded column and the database row both contain the task.

## Gotchas

- `Add` stays disabled until the title has text and the board has loaded. An empty textbox is not a failed save.
- The three columns are regions named `To do`, `In progress`, and `Done`. A task that appears only in `In progress` is not this journey.
- Showing archived cards hides the active columns' usual contents. Leave `Show archived` off.
- The database file is inside the disposable home. The proof copy is the path and the query result recorded by the script, not the live database after cleanup.
