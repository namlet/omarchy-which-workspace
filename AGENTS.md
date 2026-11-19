# AGENTS.md

Guidance for anyone, human or agent, working in this repo.

**Which Workspace** is an Omarchy shell plugin (`io.github.namlet.which-workspace`): a
bar button that opens a Mission Control style overlay. Every occupied Hyprland
workspace is drawn as a tiny screen, spread across a translucent card along the top of the screen, with
each window at its real place showing a capture of it. Clicking a window focuses it,
switching to its workspace. While the scratchpad is down, its tile slides in above.

It is meant to be listed on [plugins.omarchy.org](https://plugins.omarchy.org), so it
is built to the marketplace's submission rules and to Omarchy's own plugin conventions
from the first commit. It runs inside the user's desktop shell, with no server,
database or deploy, so the engineering practices below say which parts apply.

## Principles

1. **Ask clarifying questions before building.** If a request is ambiguous, lay out
   the readings and ask. Never pick one silently.
2. **Minimum viable implementation.** If 20 lines solve it, don't write 200. No
   speculative features, no abstractions for single-use code.
3. **Touch only what was requested.** No drive-by refactors or reformatting.
4. **Define "done" before starting.** Turn the task into checks you can verify.
5. **Always tests.** No change merges without tests. Bug fixes start with a failing test.
6. **Build the practice, not the artifact.** A check allowed to fail, or a doc that
   describes nothing, is worse than none because it hides the gap. If something can't
   be done properly yet, record it as open in `docs/production-readiness.md`.
7. **Take Omarchy facts from Omarchy**: the installed source under
   `/usr/share/omarchy/shell/` and the upstream docs (`docs/omarchy-shell.md`,
   `docs/testing.md`, `manual/32-shell-plugins.md` in `omacom/omarchy`), never from
   memory. The shell's APIs change between releases.

Features and scope are decided case by case with Nathan. Don't build speculatively.
New dependencies, new plugin kinds (service, panel, overlay) or new top-level
directories need his OK first.

## Layout

Follows the layout of Omarchy's first-party plugins and the marketplace rules:

| Path | What |
|------|------|
| `manifest.json` | Plugin manifest at the repo root. `id` is permanent once published. |
| `BarWidget.qml` | Entry point: thin shell adapter (bar button, `OverlayWindow` with scrim and translucent card, Hyprland data, live `ScreencopyView` thumbnails). No logic worth testing lives here. |
| `Model.js` | All logic as pure functions (grouping, geometry, labels, validation), ending in the guarded `module.exports` block so both QML and Node load it. |
| `components/` | Drawing in plain QtQuick, no `qs.*` or Quickshell imports, so it loads headless: `WorkspaceGrid`, `WorkspaceTile`, `Thumbnail`. Text arrives translated. |
| `tools/preview.qml` | Mockup with made-up windows through the real model and components: `make preview` (or `PNG=out.png`). |
| `i18n/*.json` | Flat string catalogs, one per Omarchy language code. `en.json` is the fallback. |
| `tests/*.test.js` | `node --test` unit tests for `Model.js`. |
| `tests/tst_*.qml` | Headless `qmltestrunner` tests for `components/`. |
| `README.md`, `LICENSE` | Required at the root by the marketplace. |
| `preview.png` | Marketplace screenshot, also shown in the README. Retake it on a staged desktop with public content only: it is published. |

No symlinks anywhere in the tree: `omarchy plugin validate` rejects them.

## Omarchy plugin rules

From the shell docs and the marketplace's SUBMISSION.md and SECURITY.md:

- **Untrusted text.** Window titles and classes come from arbitrary apps. Every `Text`
  sets `textFormat: Text.PlainText`. `Model.cleanText` bounds their length. Values
  reaching `Hyprland.dispatch` or `bar.run` are validated (`Model.normalizeAddress`) or
  shell-quoted (`Util.shellQuote`), never interpolated raw. Each sink has a test with
  markup-shaped input.
- **No polling.** State comes from Quickshell's `Hyprland` service, which signals on
  change. A `Timer` that starts a `Process` needs a written reason in this file.
  Thumbnails are still captures taken each time the overlay opens, never streamed,
  except the scratchpad's while it is down and the overlay is open (a single capture
  catches it mid-slide). Captures are shown through a mipmapped `ShaderEffectSource`
  so they scale down smoothly. Nothing is captured while the overlay is closed, and
  a window is captured only when `Model.canCapture` confirms Hyprland places it on a
  present monitor: starting a capture of a window with no monitor (around monitor
  sleep, wake and unplug) crashes Hyprland 0.56.2 in `CScreenshareSession::init`.
  That check can't close the gap between the plugin's last look and the capture
  request, so nothing is captured at all before Hyprland 0.57.0
  (`Model.capturesSupported`, from one `hyprctl version -j` run at startup, no timer).
  All captures together stay within `Model.CAPTURE_BUDGET` (128 MB, workspaces on
  screen first): a capture buffer is the window at full resolution however small it
  is drawn. A monitor coming or going closes the overlay. Geometry and monitor snapshots are
  refreshed on Hyprland events (window opened or moved, floating toggled, scratchpad,
  monitor added or removed), never on a timer.
- **Theme and motion.** Colors from `bar.*` or `Commons.Color` (always through the
  `qs.Commons as Commons` alias), sizes from `Style.*`, durations through
  `Style.duration()`. Use the `qs.Ui` kit (`BarIconButton`, `KeyboardPanel`,
  `OverlayWindow`, `BorderSurface`, `PanelKeyCatcher`) rather than building our own
  surfaces. The scrim and card colors come from the theme (`Commons.Color.menu.*`).
- **Translations.** Every user-facing string goes through `strings.t()` or
  `strings.tn()`, read inside a binding, with whole sentences and `%1` placeholders.
- **Never** start a second Quickshell process, overwrite user config without explicit
  consent, use `sudo`/`pkexec`, pipe downloads into a shell, or ship binaries. Each of
  these blocks or flags a marketplace listing.
- **Glyphs.** Write Nerd Font glyphs as `"\u{F003B}"` escapes, not raw characters:
  editing tools can strip multi-byte codepoints.

## Branches and commits

`main` ← `develop` ← `feature/*`. Branch off `develop` and open a pull request back
into it. GitHub enforces this with two rulesets, "Protect develop" and "Protect
main": pull requests only, the `make test (Arch Linux)` check passing, no force
pushes or deletion, and no bypass, admins included. No approval is required while
there is a single maintainer. Only `develop` requires the branch to be up to date
before merging. `main` only ever receives `develop`, which already holds all of its
code, so `develop` showing "behind" `main` by release merge commits is expected and
needs no sync. Releases merge `develop` into `main` and are tagged there (`v0.1.0`), with
`manifest.json`'s `version` bumped in the same PR. Commits are small, lowercase
imperative, no prefixes. No secrets in the repo, ever: a secret that reaches a commit
is leaked even if deleted. Rotate it and tell Nathan.

## Engineering practices

Everything that applies is in place, automated and enforced before the marketplace
submission.

- **Source control.** Git, `.gitignore` written first, PRs only on `main` and
  `develop` (enforced by the ruleset), gitleaks over the full history in CI. Secret
  scanning is our CI's job, not GitHub's code-security settings, by choice.
- **CI/CD.** `.github/workflows/checks.yml` runs `make test` and gitleaks on every
  push and PR, in an Arch container so Node matches what users get. Actions are
  pinned to commit SHAs, `permissions: contents: read`, with a job timeout. Dependabot
  keeps the pins current. Delivery is the git repo itself (`omarchy plugin add`
  follows the default branch), so a release is a tag on `main`. Rollback means
  reverting on `main`; users pick it up with `omarchy plugin update`.
- **Infrastructure.** Not applicable: nothing is hosted. The runtime contract is the
  Omarchy shell; record the oldest Omarchy version tested in the README.
- **Testing.** Logic in `Model.js` with Node tests, drawing in `components/` with
  headless `qmltestrunner` tests, both run in CI. QML that imports `qs.*` or
  Quickshell cannot load outside the running shell, so `BarWidget.qml` gets the
  **manual smoke test** below before every release.
- **Security.** The rules above, plus: no network access, no
  commands built from window data, no new dependency without Nathan's OK. Approval for
  the marketplace listing is not a security review.
- **Observability.** The shell logs to the journal: `journalctl --user -t
  omarchy-shell -f`. Any `console.warn` is in English and contains no window titles.
  Error tracking and metrics don't apply.
- **Disaster recovery.** Not applicable: the plugin stores no data. If it ever stores
  any, keep it outside the plugin folder (edits there trigger a reload), under
  `$XDG_STATE_HOME`.
- **Documentation.** README has Install, Usage, Configure, Update and Remove
  sections, plus Development. Docs change in the same PR as the code.

`docs/production-readiness.md` records, per practice, what is in place, what is open
and who owns it. Answer "is it ready?" from that file, separating what was seen
working from what was reported.

## Manual smoke test

Run against the live shell before every release, and after any change to
`BarWidget.qml`. With the checkout linked in and enabled
(`ln -s "$PWD" ~/.config/omarchy/plugins/io.github.namlet.which-workspace` then
`omarchy-shell shell rescanPlugins`, then
`omarchy plugin enable io.github.namlet.which-workspace`). The shell does not watch
files behind the symlink (it logs "Module path ... is outside of the config folder"),
so run `omarchy restart shell` after every edit; disabling and re-enabling is not
enough, the old components stay cached:

1. Click the bar button: the screen dims and a card slides down from the top with a tile per occupied
   workspace, numbered as the bar numbers them, windows at their real positions,
   each showing a capture of that window (including on workspaces not on screen).
2. Open or close a window while the overlay is up: the tiles update.
3. Click a window on another workspace: that workspace shows with that window
   focused, and the overlay closes. Repeat across two monitors if available: tiles
   then carry the monitor's name.
4. With the overlay open, press the scratchpad hotkey: an unlabelled scratchpad tile
   slides down above the others; press it again and the tile slides away. With the
   scratchpad hidden, nothing about it shows.
5. Arrow keys move the highlight, Enter focuses, Escape closes, Tab moves to the next
   bar panel.
6. Disable, re-enable, `omarchy restart shell`, and `omarchy plugin remove`: no errors
   in `journalctl --user -t omarchy-shell`.

## On every change

Tests added or updated and passing (`make test`), `omarchy plugin validate .` clean,
no secrets in the diff, README and this file updated in the same PR, and the status
file updated if a gap opened or closed.

## For the owner

These need Nathan's decision. Record each with a date in the status file.

- Before submitting: confirm the id is unused on plugins.omarchy.org, and pick
  category `Desktop` and tags `workspaces`, `hyprland`, `bar`.

The repo itself (`namlet/omarchy-which-workspace`, public) and its branch rulesets are
managed with `gh`: `gh api repos/namlet/omarchy-which-workspace/rulesets` lists them.
