# DeepTutor verification map

This directory is the maintained source for verifying the user-facing behavior of the DeepTutor web app. Read the index before driving the app, then use the matching feature file as the recipe.

## Baseline preconditions

- Launch with `.cursor/skills/verify-deeptutor/scripts/launch.sh`. The home is `/tmp/deeptutor-verify-$RUN_ID`, authentication is off, and the UI language is English.
- The frontend origin is the `FRONTEND_URL` in `run/current.env` (loopback, port chosen at launch). The product default of port 3782 is not required.
- Run `.cursor/skills/verify-deeptutor/scripts/doctor.sh` and require the recorded version, home, ports, disabled auth, and English language.
- Never drive an instance that was not started by this verification run.
- Chat and knowledge-base creation need provider credentials that a fresh home does not have. Those journeys fail closed. They are not skipped.

## Driving conventions

- Start every recipe from the baseline state unless its preconditions say otherwise.
- Prefer ARIA roles and accessible names over CSS selectors or DOM position.
- Treat every command as literal. Keep quoted names and flags unchanged.
- Run a mapped journey through `.cursor/skills/verify-deeptutor/scripts/drive.mjs <feature>`.
- The browser locale is `en-US`. A home whose `interface.json` language is not `en` is not this baseline.
- Restore nothing by deleting proof artifacts. Cleanup may delete the disposable home after evidence has been copied.

## Proof and skip reporting

- Capture the user action and the resulting state, not only the final screen.
- UI proof includes an ARIA snapshot and a screenshot. The document title is `DeepTutor`.
- A notebook mutation also includes `deeptutor notebook show <id> --format json` against the same home.
- Appearance, task-board, and notebook proofs include the stored file or row, not only the reloaded page.
- Record the feature id and entry point in `result.json` with every artifact.
- Report an unreachable path with the attempted command and the unmet precondition.
- Do not report a skipped entry point as verified through a different path.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the user-visible behavior. It then uses exactly four H2 sections in this order.

1. `Sub-features` lists short IDs with one line for each behavior.
2. `How to get to it (user POV)` lists every user entry point.
3. `Driving it with verify-deeptutor` starts with `Preconditions:` and uses labeled bullets that pair each user action with an exact command and observable result.
4. `Gotchas` lists traps that can waste or invalidate a verification run.

Keep implementation details out of the map. Name only user paths, stable handles, required state, commands, and observable proof.

## Features

- [Notebooks](./notebooks.md) covers creating a notebook in the browser and reading it back from the notebook CLI.
- [Appearance](./appearance.md) covers choosing the Dark theme, applying it, and seeing it after reload.
- [Task board](./task-board.md) covers adding a task and finding it again in To do.
- [Chat](./chat.md) covers sending a prompt from Home and reading the tutor's reply.
- [Knowledge bases](./knowledge.md) covers creating a knowledge base from Knowledge Center.
