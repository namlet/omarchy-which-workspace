# Production readiness

Status per engineering practice in [AGENTS.md](../AGENTS.md). Last updated 2026-11-16.

| Practice | In place | Open | Owner |
|---|---|---|---|
| Source control | Git, public GitHub remote, `.gitignore`, gitleaks over full history in CI; rulesets on `main` and `develop` (PRs only, required check, no force push or deletion, no bypass) since 2026-11-15; up-to-date requirement dropped on `main` 2026-11-16, so releases need no back-merge | none | Nathan |
| CI/CD | `checks.yml` (make test + gitleaks, pinned SHAs, read-only token, timeout), Dependabot for actions; first runs green on `main` and `develop` 2026-11-15 | none | Nathan / agent |
| Infrastructure | N/A, nothing hosted; tested on Omarchy 4.5.0 with Quickshell 0.3.2 (recorded in the README) | none | agent |
| Testing | 25 Node tests on `Model.js`, 11 headless QML tests on `components/`, qmllint, all in `make test` | Smoke test, 2026-11-15, one monitor: steps 1 and 4 seen working by the agent (overlay, live captures of off-screen workspaces, scratchpad sliding in as just its window); everyday use, including clicking through to windows, reported working by Nathan. 0.1.1 (2026-11-16): shell restarted, overlay opened and closed with no plugin errors in the journal; the crash fix itself not reproduced (needs Hyprland with no outputs). Not yet run: step 6 (disable, re-enable, restart, remove) and anything on two monitors | Nathan / agent |
| Security | Plain-text sinks, validated dispatch addresses, bounded text, no network/privileges; window captures only while the overlay is open (0.1.1) and only of windows on a present monitor (0.1.2: Hyprland 0.56.2 crashes when a capture starts for a window with no monitor; crashes 2026-11-16 twice, and 2026-11-17 during agent testing with the monitor off); secret scanning in our CI (GitHub code-security settings not used, by choice) | none | Nathan |
| Observability | Shell journal (`journalctl --user -t omarchy-shell`) | none | n/a |
| Disaster recovery | N/A, no stored data | none | n/a |
| Documentation | README (install/usage/configure/update/remove, screenshot), AGENTS.md, marketplace `preview.png` (staged desktop, public content only) since 2026-11-15 | none | Nathan |
