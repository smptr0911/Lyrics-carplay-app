# PR review and repair

[pr-automation.yml](../.github/workflows/pr-automation.yml) admits opened, updated,
reopened and ready-for-review PRs targeting `main`, including drafts, then calls
the reusable [pr-agent.md](../.github/workflows/pr-agent.md) agent workflow. It accepts only
same-repository PRs; forks and generated `pr-fix/` or `ci-repair/` branches are
excluded. The agent reviews the current revision and tests code in gh-aw's Linux
sandbox. It publishes one advisory COMMENT review, never an approval.

For a demonstrated code defect it makes one focused repair attempt. All
available checks must pass before publication. A candidate becomes a separate
draft PR from `pr-fix/<PR-number>-<full-SHA>` into the original PR's branch. A
human reviews and merges that companion PR. Updating the original PR triggers
CI and a new review; the automation never pushes to its original branch or main.
It never weakens tests or bypasses review. Simulator tests and device builds
are explicitly unavailable inside the Linux sandbox; real macOS PR CI must pass.

Read-only admission runs before inference and uses paginated run history plus
review markers `pr-agent-sha:<full-SHA>` to limit each PR revision to one attempt.
Reruns and stale heads are rejected; API errors fail closed. Keep review markers
and run history, especially for crashes before publication. Deleting evidence
removes historical deduplication guarantees. Each agent execution has a
20-minute, 35-turn, 100-AIC cap. No workflow waits or retry loops are configured.

The reviewer uses `COPILOT_GITHUB_TOKEN` for inference and the dedicated App
only in downstream safe-output jobs to post its COMMENT review and fix PR. This is a custom gh-aw reviewer; GitHub's separate native
Copilot review product may still be blocked by its account quota. This workflow
cannot replenish quota, change billing, or guarantee that inference is available.

Repair publication uses the dedicated GitHub App from [CI repair setup](ci-repair.md).
The App private key is confined to safe-output/reporting jobs, outside the
agent. Both settings are required for live publication. Missing App
configuration leaves a failed Actions run and may prevent issue reporting;
normal agent artifacts preserve any candidate patch. No CLI token is reused.

## GitHub App setup

1. Open [the prefilled registration form](https://github.com/settings/apps/new?name=Lyrics-CarPlay-Repair-smptr0911&url=https%3A%2F%2Fgithub.com%2Fsmptr0911%2FLyrics-carplay-app&public=false&webhook_active=false&contents=write&pull_requests=write&issues=write&actions=read&checks=read).
   Verify the settings and create the private App. Webhooks stay disabled.
2. Copy its **Client ID** to repository Actions variable `CI_REPAIR_APP_CLIENT_ID`.
   This is the client ID, not the numeric App ID and not an OAuth client secret.
3. Generate a private key in the App's settings. Add the entire downloaded PEM
   as repository Actions secret `CI_REPAIR_APP_PRIVATE_KEY`. Never post the key
   in a PR, issue, chat, log, or committed file.
4. Select **Install App** and install on only `Lyrics-carplay-app`. The original
   setup grants Contents/Issues/Pull requests read/write and Actions/Checks read;
   no Administration, Workflows, organization, or main-ruleset bypass access.

## Main protection

The versioned [ruleset](../.github/automation/main-ruleset.json) requires a PR,
one approving human review after the latest push, resolved conversations, and
up-to-date passing `test`, `simulator-tests`, `device-release-build` and
`whitespace` checks from GitHub Actions. It blocks force pushes and deletion,
with no actor bypasses. A solo author needs another human reviewer; the agent
cannot approve its own work or satisfy that requirement.

An administrator can apply it to the existing ruleset with:

```sh
gh api --method PUT repos/smptr0911/Lyrics-carplay-app/rulesets/25595818 --input .github/automation/main-ruleset.json
```

## Validation

```sh
gh aw compile pr-agent --strict --validate
node --test .github/scripts/*.test.cjs
python3 scripts/validate_project.py
python3 -m unittest discover -s backend/tests -v
git diff --check
```

Local tests use API doubles; compilation does not prove runtime credentials or
successful repairs. Controlled live verification uses disposable test PRs and
must record the exact tested commit, review URL, repair PR, validation results,
and any unavailable checks. Never merge an intentional regression into main.

### Verification record

On November 15, 2026, the two owner-approved live runs reached the agent but
failed before executing review/repair tools. Both resolved `auto` to
`claude-sonnet-5.5` and received repeated upstream HTTP 502 responses:
[implementation run](https://github.com/smptr0911/Lyrics-carplay-app/actions/runs/43777220906),
[intentional-regression run](https://github.com/smptr0911/Lyrics-carplay-app/actions/runs/43777236071).
The first run also confirmed that publication lacked a nonempty App client ID.
No automated review or fix was produced by these runs. The implementation PR's
backend, whitespace, simulator and unsigned device Release CI checks passed.

The follow-up source pins `gpt-6.1-sol` for both PR and main-CI repair. That model
and its `/responses` support were advertised in the failing run's own Copilot
catalog. Compilation and source review do not establish that the alternate
model works; live verification remains required after credentials are configured.
