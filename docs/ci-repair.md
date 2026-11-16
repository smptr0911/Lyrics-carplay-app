# Automated CI repair

The source [ci-repair.md](../.github/workflows/ci-repair.md) compiles to
[ci-repair.lock.yml](../.github/workflows/ci-repair.lock.yml). Commit both files.
[PR automation](pr-agent.md) provides review and repair before merge.

## Activation and repair

The listener runs only after a completed, failed **push** CI run on `main` in
this repository. Its exact existing workflow names are:

| Workflow | File | Validation |
| --- | --- | --- |
| `Backend and repository checks` | `.github/workflows/backend-ci.yml` | Project structure, backend tests, automation guard tests |
| `iOS CI` | `.github/workflows/ios-ci.yml` | Simulator unit/UI tests and unsigned device Release build |

`PR checks` only validates PRs and is not a repair trigger. Forks, PR events,
manual validation dispatches, successful/cancelled runs and other branches do
not start the main repair agent. The listener must be merged into `main`.

Copilot reads failed logs and makes one bounded attempt to repair an evidenced
code/build/test defect. All available local checks must pass before it creates
a separate draft PR from `ci-repair/<full-sha>` to `main`. An issue records the
attempt, root cause, test evidence, unavailable checks and outcome. Unfixable
failures are reported without a speculative PR. Tests must never be disabled,
skipped or weakened; CI/validation scripts and agent instructions cannot be
changed by repair outputs. The automation never approves, merges or pushes to main.

## Authentication: a GitHub App is not required

This version uses two credentials for separate purposes:

| Credential | Purpose | Permission boundary |
| --- | --- | --- |
| `COPILOT_GITHUB_TOKEN` secret | Copilot inference | Fine-grained PAT with Copilot Requests: read; no repository write scopes needed |
| Automatic `GITHUB_TOKEN` | Logs, reports and safe-output publication | Agent/admission read-only; separate generated output jobs receive scoped writes |

Do not reuse the inference PAT for repository writes. No App client ID, private
key, publishing PAT or `GH_AW_CI_TRIGGER_TOKEN` is required.

In **Settings → Actions → General → Workflow permissions**, retain the default
read-only token setting and enable **Allow GitHub Actions to create and approve
pull requests**. GitHub couples creation and approval in that setting, but these
workflows expose no approve/merge output: the PR reviewer allows only COMMENT.
The agent has no repository write token, and main's ruleset still requires an
independent human review plus passing CI without bypass actors.

GitHub can put PR-event workflows created by `GITHUB_TOKEN` into an
approval-required state. To keep validation automatic, each successful create-PR
output is followed by three dependent gh-aw `dispatch-workflow` outputs:
`backend-ci`, `ios-ci` and `pr-checks`. They run the existing test jobs on the
**exact repair branch**, with `base_ref: main` for whitespace validation.
Dispatches are capped at three and restricted to those validation workflows and
the exact deterministic fix branch. Only downstream safe-output jobs gain
`actions: write`; the agent retains `actions: read`. No agent can dispatch itself.

The existing CI commands and job names are unchanged. Their new
`workflow_dispatch` entrypoints ensure the resulting commit receives backend,
macOS/iOS and whitespace checks without an extra credential or human approval
of PR-event runs. Explicit dispatch validates the candidate head commit; the
main ruleset also requires up-to-date checks before merge.

See GitHub's [GITHUB_TOKEN event rules](https://docs.github.com/en/actions/concepts/security/github_token)
and [Actions repository settings](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository).

## Attempt and loop limits

The read-only [admission guard](../.github/scripts/ci-repair-admission.cjs) runs
before Copilot. It validates the event/repository/current main SHA, rejects
reruns and stale commits, and paginates prior repair runs, issues, PRs and
branches. Workflow concurrency serializes admission through output completion.
An earlier repair run for the same failed commit consumes the attempt even if
it failed, timed out, was skipped or was cancelled. Two CI failures for one
commit cannot start two repair attempts. API errors fail closed.

Preserve issue/PR markers `ci-repair-sha:<full-sha>` and run history for crashes
that produced no ledger. Deleted/expired evidence limits historical deduplication.
Generated fix branches and workflow_dispatch validation events cannot reactivate
main repair. There are no dispatch retries, agent-to-agent dispatches or waits
for external workflows. Older failures are skipped when main has advanced.

## Validation and merge policy

The normal agent is a Linux firewall sandbox. It runs project validation,
backend tests, guard tests and whitespace checks. Simulator XCTest/UI tests and
the unsigned device build must be marked **NOT RUN — requires macOS/Xcode**
inside that sandbox. Structural validation is not a Swift build. The dispatched
`iOS CI` jobs run on `macos-15`; only actual successful jobs count as Apple checks.
Physical-device testing is not supplied by CI.

The [main ruleset](../.github/automation/main-ruleset.json) requires a PR,
independent approval after the latest push, resolved conversations, and passing
up-to-date `test`, `simulator-tests`, `device-release-build` and `whitespace`
checks. It blocks deletion/force pushes and gives no actor a bypass. Draft PRs
stay unmerged until a human reviews and the checks pass.

Both agents pin the currently advertised Copilot model `gpt-6.1-sol`.
The earlier automatic model selection returned repeated HTTP 502 responses;
[the verification record](pr-agent.md#verification-record) distinguishes that
failed live test from compilation of the new configuration.

```sh
gh aw compile ci-repair pr-agent --strict --validate --actionlint --shellcheck
node --test .github/scripts/*.test.cjs
python3 scripts/validate_project.py
python3 -m unittest discover -s backend/tests -v
git diff --check
```

Compilation does not run Copilot, verify model access, publish a PR or prove a
repair works. No further live test is permitted without owner approval.

## Optional App alternative

An App is optional if you prefer normal push/PR events to start CI naturally
instead of explicit validation dispatches. Create a private App, disable its
webhook, and install it on only this repository. For a global safe-output App
covering issue reports and PR publication, grant Contents, Pull requests and
Issues read/write, plus Actions and Checks read for generated diagnostics.
No Administration, Workflows, organization or ruleset-bypass permissions are needed.

Store its Client ID as repository variable `CI_REPAIR_APP_CLIENT_ID` and its
entire generated PEM private key as secret `CI_REPAIR_APP_PRIVATE_KEY`. Never
share the key in chat or commit it. Switching to this alternative requires a
reviewed workflow configuration change; these optional values are not read by
the current GITHUB_TOKEN-based version.
