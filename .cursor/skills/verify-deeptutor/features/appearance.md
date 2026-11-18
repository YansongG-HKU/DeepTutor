# Appearance

Appearance lets a learner choose a theme, apply it, and see that theme on the next visit.

## Sub-features

- `appearance-open` opens the Appearance settings page.
- `appearance-stage` selects Dark without applying it.
- `appearance-apply` applies the staged theme.
- `appearance-persist` shows Dark after reload and stores it in the home's interface settings.

## How to get to it (user POV)

- Choose `Settings` in the sidebar, then choose `Appearance`.
- Open `/settings/appearance` on the frontend origin.
- Open `/settings#appearance`. That address redirects to `/settings/appearance`.

## Driving it with verify-deeptutor

Preconditions:

- Doctor reports the verification frontend, the disposable home, disabled auth, and English.
- The seeded theme is `snow`, shown on the theme tile `Default`.

- **Open Settings.** Choose `Settings`. `scripts/drive.mjs appearance` clicks the link named `Settings`.
- **Open Appearance.** Choose `Appearance`. The script clicks the link named `Appearance`. The heading `Appearance` is visible.
- **Stage Dark.** Choose the `Dark` theme tile. The script clicks the button named `Dark`. That button's `aria-pressed` value is `true`. A status reads `Unsaved changes`. The document does not need the `dark` class yet. The script writes `staged.png` and `staged.aria.txt`.
- **Apply.** Choose `Apply changes`. The script clicks the button named `Apply changes`. The button leaves the page and the document element has the class `dark`.
- **Reload.** Reload Appearance. The document element still has the class `dark` and the heading `Appearance` is visible. The script writes `applied.png` and `applied.aria.txt`.
- **Stored setting.** `<home>/data/user/settings/interface.json` contains `"theme": "dark"`. The script copies that file next to the screenshots.

The command for this whole journey is:

```bash
.cursor/skills/verify-deeptutor/scripts/drive.mjs appearance
```

`result.json` has `"pass": true` only when the reloaded document has class `dark` and `interface.json` stores `dark`.

## Gotchas

- Choosing a tile stages a draft. The palette changes for the whole app only after `Apply changes`.
- The tile labeled `Default` stores the theme id `snow` and adds the class `theme-snow`. The tile labeled `Cream` stores `light`. The tile labeled `Dark` stores `dark` and adds the class `dark`. The tile labeled `Glass` stores `glass` and adds both `dark` and `theme-glass`.
- The browser key `deeptutor-theme` is applied before the saved file on the next load. A dark document with `interface.json` still set to `snow` is not a pass.
- `Apply changes` is hidden while there is nothing to apply. Wait until `Unsaved changes` is visible before clicking it.
