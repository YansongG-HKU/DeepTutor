---
name: verify-deeptutor
description: "Drive the DeepTutor local web app the way a learner does. Use after deeptutor start --dev on an isolated runtime home (frontend on 127.0.0.1, default product port 3782) to prove notebooks, appearance, the task board, chat, or knowledge bases. Reach for it when a source checkout change should be exercised in the browser, not only by unit tests."
---

# Verify DeepTutor

DeepTutor's primary local surface is the web app. From a source checkout, `deeptutor start --dev` serves the Next.js UI and the FastAPI backend together. The browser talks to the frontend origin; Next proxies `/api/*` and `/ws/*` to the backend. A fresh home has authentication off and no language-model or embedding credentials.

Other surfaces exist and are not what this skill drives: the Typer CLI (`deeptutor run`, `deeptutor chat`, `deeptutor notebook`) and the HTTP/WebSocket API. Notebook verification uses `deeptutor notebook show` only as a second view of a notebook the browser created.

Two verification instances can run side by side only with different homes, ports, and state files. The default state file is one instance. Do not drive a home you did not start.

## Launch

From the repository root, install once if these are missing:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -e .
( cd web && npm ci --legacy-peer-deps )
web/node_modules/.bin/playwright install chromium
```

`python3 -m venv` needs the `venv` module (`python3-venv` on Debian/Ubuntu). The launcher's own fallback is `npm ci` without `--legacy-peer-deps`; install the web dependencies with the command above so that fallback does not run.

Start an isolated app:

```bash
.cursor/skills/verify-deeptutor/scripts/launch.sh
```

The script:

- Refuses to start when `.cursor/skills/verify-deeptutor/run/current.env` still points at a live launcher. A second instance needs `VERIFY_ALLOW_CONCURRENT=1` and a different `VERIFY_STATE`.
- Picks two free loopback ports and writes them into `<home>/data/user/settings/system.json` before startup. Unset `BACKEND_PORT`, `FRONTEND_PORT`, `PORT`, and `DEEPTUTOR_HOME` in the launching shell; those variables override the home.
- Writes `interface.json` with `language` and `response_language` set to `en` and `theme` set to `snow`. Selectors in this skill are the English strings.
- Runs `<venv>/bin/python -m deeptutor_cli.main start --home <home> --dev --no-browser --detach`.
- Waits until `<home>/data/user/runtime/launcher.json` has `"status": "ready"`. Ready means the launcher logged `Backend is ready.` and `Frontend is ready.` after both ports accepted HTTP. `DEEPTUTOR_BACKEND_READY_TIMEOUT` defaults to 180 seconds and `DEEPTUTOR_FRONTEND_READY_TIMEOUT` to 300 seconds inside this script, because the first Next.js compile is part of becoming usable.

The home is `/tmp/deeptutor-verify-$RUN_ID`. State is `run/current.env`. Evidence for the run is created at `.cursor/skills/verify-deeptutor/artifacts/$RUN_ID/` and a copy of the state file is written there as `instance.txt` (not `*.env`, which this repository ignores).

Usable means `curl -fsSL "$FRONTEND_URL/"` follows the redirect to `/chat` and returns HTML containing `DeepTutor`, and `curl -fsS "$BACKEND_URL/api/system/status"` returns `"backend": {"status": "online", ...}`. A port that accepts TCP while Next is still compiling is not treated as ready; the launcher only marks ready after an HTTP response.

## Doctor

```bash
.cursor/skills/verify-deeptutor/scripts/doctor.sh
```

Doctor is read-only. It exits 0 only when all of these are true:

- The launcher pid from the state file is alive, its command is `deeptutor_cli.main`, and that command includes this home.
- `deeptutor/__version__.py` matches the version recorded at launch.
- `launcher.json` is `ready` and its ports match the state file.
- `auth.json` has `"enabled": false`. Journeys in this skill have no password.
- `interface.json` has `"language": "en"`.
- The frontend HTML identifies DeepTutor and the backend status endpoint reports the backend online.
- The processes listening on both ports are in the launcher's process tree.
- The Playwright Chromium binary used by `drive.mjs` is installed.

Anything else is not worth driving. Doctor does not click the UI and does not restart the app.

## Drive

Run doctor, then one feature:

```bash
.cursor/skills/verify-deeptutor/scripts/drive.mjs notebooks
.cursor/skills/verify-deeptutor/scripts/drive.mjs appearance
.cursor/skills/verify-deeptutor/scripts/drive.mjs task-board
.cursor/skills/verify-deeptutor/scripts/drive.mjs chat
.cursor/skills/verify-deeptutor/scripts/drive.mjs knowledge
```

`drive.mjs` reads `VERIFY_STATE` or `run/current.env`, opens Chromium against `FRONTEND_URL`, and sets the browser locale to `en-US` at 1280×800. It runs headless when `DISPLAY` is unset and headed when `DISPLAY` is set. Set `VERIFY_CHROMIUM_NO_SANDBOX=1` only when Chromium refuses to start inside a restricted container.

Stable handles the script uses, from the product UI:

| Feature | Handles |
| --- | --- |
| Shell | home link `a[href="/"]` containing an image named `DeepTutor` (expanded accessible name `DeepTutor DeepTutor`, collapsed accessible name `DeepTutor`), document title `DeepTutor` |
| Notebooks | link `Learning Space`, link `Notebooks`, heading `Notebooks`, button `New notebook`, placeholders `Notebook name` and `Description (optional)`, button `Create`, heading level 2 with the notebook name |
| Appearance | link `Settings`, link `Appearance`, heading `Appearance`, button `Dark` (`aria-pressed`), status `Unsaved changes`, button `Apply changes`, `document.documentElement` class `dark` |
| Task board | link `Task Board`, heading `Task Board`, textbox `New task`, button `Add`, region `To do` |
| Chat | link `Home`, textbox `How can I help you today?`, button `Send`, `[data-chat-message-role="assistant"]` |
| Knowledge | link `Knowledge Center`, button `New knowledge base`, dialog `Create knowledge base`, placeholder `e.g. project-papers`, button `Create` inside that dialog |

The per-feature recipes, including the exact pass and fail conditions, are in `features/`. A missing credential is a failed journey. Do not point the app at a mock model server to make chat or knowledge-base creation pass.

## Evidence

Proof for a feature is written to:

```text
.cursor/skills/verify-deeptutor/artifacts/<run-id>/<feature>/
```

Every journey writes `result.json` with `feature`, `pass`, `run_id`, `frontend_url`, and `version`. A passing UI journey also writes a screenshot and an ARIA snapshot of the action (`draft.png`, `draft.aria.txt` or `staged.*`) and of the resulting state (`saved.png`, `saved.aria.txt` or `applied.*`). The document title in the page is `DeepTutor`.

Side effects are checked outside the screen that just changed:

- Notebooks: `deeptutor notebook show <id> --format json` with `DEEPTUTOR_HOME` set to the verification home, plus the notebook JSON file under that home. Both must contain the name `Verification notebook` and the description `Created from the browser`.
- Appearance: `data/user/settings/interface.json` must contain `"theme": "dark"` after reload. The `deeptutor-theme` localStorage key is not sufficient; startup prefers it over the file.
- Task board: a row in `task-board/tasks.sqlite` with that title and status `todo`.
- Chat: an assistant message with text and no alert inside it. `llm.status` other than `configured` fails the journey before send.
- Knowledge: the created base is still listed after reload. `embeddings.status` other than `configured` fails the journey while the Create button stays disabled.

`result.json` with `"pass": false` is a failed proof. Do not describe that run as verified.

## Cleanup

```bash
.cursor/skills/verify-deeptutor/scripts/cleanup.sh
```

Cleanup calls `deeptutor.runtime.launcher.stop(home, timeout=60)` for the pid in the state file. It does not kill by process name. `stop` can return as soon as the detached state file is cleared, so the script then waits up to 15 seconds for `/proc/<pid>` to disappear and treats a zombie as gone. On success it deletes only a home under `/tmp/deeptutor-verify-*` and removes `run/current.env` when that file names the same run. It copies the last 120 lines of `launcher.log` into the evidence directory first.

Cleanup never deletes `.cursor/skills/verify-deeptutor/artifacts/`. If stop times out, the script exits 1, leaves the home in place, and leaves the evidence in place.

## Helpers

| Script | Invocation |
| --- | --- |
| `scripts/launch.sh` | `.cursor/skills/verify-deeptutor/scripts/launch.sh` |
| `scripts/doctor.sh` | `.cursor/skills/verify-deeptutor/scripts/doctor.sh` |
| `scripts/drive.mjs` | `.cursor/skills/verify-deeptutor/scripts/drive.mjs <feature>` |
| `scripts/cleanup.sh` | `.cursor/skills/verify-deeptutor/scripts/cleanup.sh` |
| `scripts/common.sh` | Sourced by the shell helpers. It resolves the repo root, `.venv/bin/python`, the state file, and the Playwright browser path. |

All four entry points are executable. `common.sh` is a library and is not invoked directly.

## Maintenance

When a route, accessible name, or startup command changes, update the matching file under `features/` and re-run that feature. Use `/maintain-verification-skill` to keep this map aligned with the app.
