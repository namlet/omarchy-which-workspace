# Production readiness

Status per engineering practice in [AGENTS.md](../AGENTS.md). Last updated 2026-11-15.

| Practice | In place | Open | Owner |
|---|---|---|---|
| Source control | Git, `.gitignore`, gitleaks in CI | No remote yet. Branch protection on `main`/`develop`. Local pre-commit secret scan. | Nathan |
| CI/CD | `checks.yml` (make test + gitleaks, pinned SHAs, read-only token, timeout), Dependabot for actions | Not yet seen running on GitHub. No release tag yet. | Nathan / agent |
| Infrastructure | N/A, nothing hosted | Record the oldest Omarchy version tested | agent |
| Testing | 22 Node tests on `Model.js`, 10 headless QML tests on `components/`, qmllint, all in `make test` | Smoke test step 1 seen working 2026-11-15 (live captures of off-screen workspaces render, overlay layout seen 2026-11-15); steps 2-6 not yet run | Nathan / agent |
| Security | Plain-text sinks, validated dispatch addresses, bounded text, no network/privileges | GitHub secret scanning + push protection | Nathan |
| Observability | Shell journal (`journalctl --user -t omarchy-shell`) | none | n/a |
| Disaster recovery | N/A, no stored data | none | n/a |
| Documentation | README (install/usage/configure/update/remove), AGENTS.md | `preview.png` for the marketplace | Nathan |
