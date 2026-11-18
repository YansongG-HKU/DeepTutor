# Verification proof

Run id: `20261118T023104Z-4385`

DeepTutor `1.6.15`, source checkout, frontend runtime `source` (`deeptutor start --dev`). Chromium ran headed because `DISPLAY=:1` was set.

## What ran

1. `.cursor/skills/verify-deeptutor/scripts/launch.sh`
   - Home: `/tmp/deeptutor-verify-20261118T023104Z-4385` (removed by cleanup)
   - Backend: `http://127.0.0.1:49417`
   - Frontend: `http://127.0.0.1:52519`
   - Launcher pid: `4409`
   - Ready when `launcher.json` status was `ready` and the log contained `Backend is ready.` and `Frontend is ready.`
2. `.cursor/skills/verify-deeptutor/scripts/doctor.sh` — exit 0. Version `1.6.15`, auth disabled, language `en`, both ports owned by the launcher tree, frontend HTML title `DeepTutor`.
3. `.cursor/skills/verify-deeptutor/scripts/drive.mjs notebooks` — exit 0.
   - Entry: sidebar `Learning Space` → `Notebooks` → `New notebook` → `Create`.
   - Name `Verification notebook`, description `Created from the browser`.
   - Reloaded the notebook page.
   - `deeptutor notebook show 68c7c2ec --format json` exited 0 and returned that name and description.
   - Stored file `data/user/workspace/notebook/68c7c2ec.json` matched.
4. `.cursor/skills/verify-deeptutor/scripts/cleanup.sh`
   - The first cleanup returned before pid `4409` had left `/proc`, so it kept the home and exited 1. The script now waits up to 15 seconds for that pid to disappear.
   - The follow-up cleanup saw the pid already gone, deleted the home, removed `run/current.env`, and left the evidence directory in place. Exit 0.

## Evidence

All of these files were still present after cleanup:

- `.cursor/skills/verify-deeptutor/artifacts/20261118T023104Z-4385/instance.txt`
- `.cursor/skills/verify-deeptutor/artifacts/20261118T023104Z-4385/launcher.log.tail.txt`
- `.cursor/skills/verify-deeptutor/artifacts/20261118T023104Z-4385/notebooks/result.json` (`"pass": true`)
- `.cursor/skills/verify-deeptutor/artifacts/20261118T023104Z-4385/notebooks/draft.png`
- `.cursor/skills/verify-deeptutor/artifacts/20261118T023104Z-4385/notebooks/draft.aria.txt`
- `.cursor/skills/verify-deeptutor/artifacts/20261118T023104Z-4385/notebooks/saved.png`
- `.cursor/skills/verify-deeptutor/artifacts/20261118T023104Z-4385/notebooks/saved.aria.txt`
- `.cursor/skills/verify-deeptutor/artifacts/20261118T023104Z-4385/notebooks/cli-show.stdout.txt`
- `.cursor/skills/verify-deeptutor/artifacts/20261118T023104Z-4385/notebooks/cli-show.stderr.txt`
- `.cursor/skills/verify-deeptutor/artifacts/20261118T023104Z-4385/notebooks/cli-show.exit.txt` (`0`)
- `.cursor/skills/verify-deeptutor/artifacts/20261118T023104Z-4385/notebooks/notebook.json`

## Pass / fail

| Step | Result |
| --- | --- |
| Launch | Pass |
| Doctor | Pass (after following the `/` → `/chat` redirect) |
| Drive `notebooks` | Pass |
| Cleanup | Pass on the follow-up run, after the pid-wait fix |
| Evidence after cleanup | Pass |

Two earlier `drive.mjs notebooks` attempts failed and were fixed before the passing run: the expanded logo link is named `DeepTutor DeepTutor`, and the description string is rendered twice. Those failed artifacts were not kept.

## Unverified

- Appearance, task board, chat, and knowledge bases were not driven. Chat and knowledge-base creation fail closed on this home: startup logged `No active LLM model is configured`, and a fresh home has no embedding model. Those journeys were not weakened or mocked.
- `deeptutor notebook create` was not used. The CLI was only the read-back of the browser-created notebook.
- `deeptutor start` without `--dev` (the production Next.js build) was not launched. This checkout's documented dev command is `--dev`.
- The public site `https://deeptutor.info/` was not driven.
- This VM needed `python3-venv` installed before `python3 -m venv .venv` would run. A machine that already has the venv module does not do that. `pip install -e .`, `npm ci --legacy-peer-deps`, and `playwright install chromium` are the skill's own setup commands.

## Maintenance

Use `/maintain-verification-skill` when routes or accessible names change. Re-run the feature you touched.
