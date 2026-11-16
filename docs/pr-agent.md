# PR review and repair

[pr-automation.yml](../.github/workflows/pr-automation.yml) admits same-repository
PRs targeting `main`, including drafts, then calls the sandboxed reusable
[pr-agent.md](../.github/workflows/pr-agent.md) workflow. Forks and generated
`pr-fix/` or `ci-repair/` branches are rejected. The agent posts an advisory
COMMENT review and never approves or merges.

For an evidenced code defect it makes one focused attempt, reruns available
tests, and creates a separate draft companion PR from
`pr-fix/<PR-number>-<full-SHA>` into the original PR's branch. Three bounded
safe-output dispatches start the existing backend, macOS/iOS and whitespace
checks on that repair commit. The whitespace dispatch receives the original
PR branch as `base_ref`. A human reviews/merges the companion PR; the original
PR's new commit then triggers fresh checks and review. Tests cannot be weakened.

## Credentials and activation

No GitHub App is required. `COPILOT_GITHUB_TOKEN` authenticates inference only;
`GITHUB_TOKEN` handles safe-output reviews, reports, PR creation and scoped CI
dispatch. The agent repository token remains read-only. See [CI repair setup](ci-repair.md)
for the GitHub PR-creation setting and validation-dispatch rationale.

The repository variable `PR_AGENT_ENABLED` must equal `true` for PR inference to
start. It is kept `false` during setup so publishing the reviewed configuration
cannot launch another live test without the owner's approval. After one-time
activation, future eligible PR revisions need no manual invocation. This switch
does not affect conventional backend/macOS/whitespace CI or main CI repair.

Native GitHub Copilot review and this custom gh-aw reviewer have different
entrypoints. This workflow cannot replenish account quota or guarantee provider
availability. It pins `gpt-6.1-sol`, which the actual failed run's Copilot catalog
advertised with `/responses` support. Successful inference still needs a live test.

## Bounds and safety

Read-only admission precedes inference. It verifies the current head, blocks
manual reruns, and checks paginated history plus attributed bot review markers.
A PR revision gets one attempt even if an earlier run failed before publication.
API errors fail closed. Preserve run history and `pr-agent-sha:<full-SHA>` review
markers; deleting evidence removes historical deduplication guarantees.

Each agent execution has a 20-minute, 35-turn, 100-AIC cap; detection has its own
100-AIC cap. Outputs allow one COMMENT review, one draft fix PR, and at most
three dispatches restricted to the exact candidate ref and the three existing
validation workflows. Agent workflow dispatch, loops and retry dispatches are
not allowed. PR code/tests execute only in the sandbox. Xcode results are never
invented; real dispatched macOS CI must pass before human merge.

The [main ruleset](../.github/automation/main-ruleset.json) requires independent
approval after the latest push and all four existing status checks, without
actor bypass. The automatic token's PR-creation setting does not grant this
agent an approval output.

## Validation

```sh
gh aw compile pr-agent ci-repair --strict --validate --actionlint --shellcheck
node --test .github/scripts/*.test.cjs
python3 scripts/validate_project.py
python3 -m unittest discover -s backend/tests -v
git diff --check
```

Local tests use API doubles and compiled permission contracts. Compilation is
not proof of successful inference, PR publication or remote test execution.

## Verification record

On November 15, 2026, the two owner-approved live runs reached the agent but
failed before review/repair tools. Both resolved `auto` to `claude-sonnet-5.5`
and received repeated upstream HTTP 502 responses:
[implementation run](https://github.com/smptr0911/Lyrics-carplay-app/actions/runs/43777220906),
[intentional-regression run](https://github.com/smptr0911/Lyrics-carplay-app/actions/runs/43777236071).
App-based publication also failed because its client ID was empty. No automated
review or fix was produced. The disposable regression PR was closed without
merging; the implementation PR's backend, whitespace, real simulator tests and
unsigned device Release checks passed on the tested revision.

The revised configuration removes the App dependency and pins `gpt-6.1-sol`.
Its compile/local/security results must be reported separately from live
results. A new live test, including activation of `PR_AGENT_ENABLED`, requires
fresh owner approval. Never merge an intentional regression into main.
