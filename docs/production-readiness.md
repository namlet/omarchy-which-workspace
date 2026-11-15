# Production readiness

Status per engineering practice in [AGENTS.md](../AGENTS.md). Last updated 2026-11-15.

| Practice | In place | Open | Owner |
|---|---|---|---|
| Source control | Git, public GitHub remote, `.gitignore`, gitleaks over full history in CI; ruleset on `main`/`develop` (PRs only, required check, no force push or deletion, no bypass) since 2026-11-15 | none | Nathan |
| CI/CD | `checks.yml` (make test + gitleaks, pinned SHAs, read-only token, timeout), Dependabot for actions; first runs green on `main` and `develop` 2026-11-15 | No release tag yet | Nathan / agent |
| Infrastructure | N/A, nothing hosted | Record the oldest Omarchy version tested | agent |
| Testing | 25 Node tests on `Model.js`, 11 headless QML tests on `components/`, qmllint, all in `make test` | Smoke test step 1 seen working 2026-11-15 (live captures of off-screen workspaces render, overlay layout seen 2026-11-15); steps 2-6 not yet run | Nathan / agent |
| Security | Plain-text sinks, validated dispatch addresses, bounded text, no network/privileges; secret scanning in our CI (GitHub code-security settings not used, by choice) | none | Nathan |
| Observability | Shell journal (`journalctl --user -t omarchy-shell`) | none | n/a |
| Disaster recovery | N/A, no stored data | none | n/a |
| Documentation | README (install/usage/configure/update/remove), AGENTS.md | `preview.png` for the marketplace | Nathan |
