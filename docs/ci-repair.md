# Automated CI repair

The source is [ci-repair.md](../.github/workflows/ci-repair.md); GitHub executes
its generated [ci-repair.lock.yml](../.github/workflows/ci-repair.lock.yml).
Both files and [.github/aw/actions-lock.json](../.github/aw/actions-lock.json)
must be committed together. The default branch is `main`.

The workflow reacts to completed **failed push runs on main** of these exact
existing workflow names:

| Workflow name | File | Checks |
| --- | --- | --- |
| `Backend and repository checks` | `.github/workflows/backend-ci.yml` | Project structure, backend unit tests, repair admission tests |
| `iOS CI` | `.github/workflows/ios-ci.yml` | Simulator unit/UI tests, unsigned device Release build |

`PR checks` is intentionally not a trigger: it only runs on pull requests.
Successful/cancelled runs, PR events, forks and other branches do not start a
repair agent. CI on repair branches cannot recursively activate this workflow.

Copilot reads the failed logs, identifies the causal error, and attempts a small
code/build/test repair. It reports infrastructure, secret, signing, missing-log,
out-of-scope and unsuccessful repairs in a `[ci-repair] <full-sha>` issue. Every
completed investigation records this issue as its attempt ledger, including
successful candidate repairs. A passing local candidate produces a **draft**
PR from `ci-repair/<full-sha>` to `main` through gh-aw safe outputs. Tests must
not be weakened or disabled. The agent cannot publish CI or validation-script
changes. It cannot approve or merge a PR or push directly to main.

## GitHub configuration

1. Merge these files into `main`; `workflow_run` listeners must exist on the
   default branch. Enable Actions, Issues, and GitHub-hosted Linux and macOS
   runners, with sufficient Actions minutes and Copilot usage budget.
2. In **Settings → Actions → General**, allow GitHub-owned actions and the
   SHA-pinned `github/gh-aw-actions/setup` action. Keep the default workflow token
   read-only. Individual compiler-generated reporting and safe-output jobs
   declare the specific write permissions they require. The agent and admission
   job retain read-only repository access.
3. Set repository secret **`COPILOT_GITHUB_TOKEN`** to a fine-grained personal
   access token owned by a user with Copilot access and the **Copilot Requests:
   read** user permission. Enable Copilot CLI access in any applicable organization
   policy. This is inference authentication, not repository write authentication.
   The workflow explicitly sets `copilot-requests: none` to select this secret
   based path, suitable for this personal repository. For an organization with
   supported organization-billed inference, you may instead change that scope
   to `copilot-requests: write` and recompile; then gh-aw uses the Actions token
   for inference. Do not add repository write permissions to the agent.
   See the [gh-aw authentication reference](https://github.github.com/gh-aw/reference/auth/#copilot_github_token).
4. Create and install a dedicated GitHub App on **only this repository**. Grant
   repository permissions **Contents: read/write**, **Pull requests: read/write**,
   **Issues: read/write**, **Actions: read**, **Checks: read**, and the automatic
   **Metadata: read** permission. No Workflows, Administration, organization or
   bypass permissions are needed. Actions/Checks reads support gh-aw's generated
   failure reporting; write scopes are for separate safe-output/reporting jobs.
   Set repository variable **`CI_REPAIR_APP_CLIENT_ID`** to its client ID and
   secret **`CI_REPAIR_APP_PRIVATE_KEY`** to its PEM private key. gh-aw mints
   short-lived, repository-scoped installation tokens outside the agent sandbox.
   No webhook configuration is required for this token-only use.
5. Use this App for PR publication as configured. App-created PRs trigger the
   existing `pull_request` CI workflows; PRs created with only `GITHUB_TOKEN`
   normally would not. The App must be permitted by any ruleset restricting
   creation of `ci-repair/*` branches, without permission to bypass main's rules.
   No extra CI-trigger PAT or `GH_AW_CI_TRIGGER_TOKEN` is needed.
6. Create an active ruleset or branch protection rule targeting **`main`**:
   require a pull request, at least **one human approving review**, dismissal of
   stale approvals, and passing status checks before merge. Apply the rule to
   administrators and give neither this App nor the Actions bot a bypass.
   Require the existing job checks `test`, `simulator-tests`,
   `device-release-build`, and `whitespace` (select the actual checks shown by
   GitHub after their first PR run). Require the branch to be up to date, or use
   a suitably configured merge queue. Disable force pushes and deletions.
   Leave auto-merge off for repair PRs; the workflow already sets it false.
   A draft alone is not an approval policy: GitHub must enforce the ruleset.

After a repair PR is created, the existing CI runs backend checks on Linux and
simulator tests/device compilation on `macos-15`. The gh-aw agent itself runs
in a Linux firewall sandbox and cannot run Xcode. Its PR must explicitly mark
Apple checks **NOT RUN — requires macOS/Xcode**, never report structural
validation as a Swift build. A maintainer must check the PR's actual macOS CI,
mark it ready for review, obtain approval, and merge only with required checks
passing. Physical device testing is not provided by these CI jobs.

## Attempt limits and failure handling

The read-only [admission guard](../.github/scripts/ci-repair-admission.cjs) runs
before activation and Copilot. Workflow-wide concurrency serializes the whole
repair, including safe outputs. It checks all pages of repair run history,
issues, PRs and branches and fails closed on API errors. One earlier failed-push
notification for the same SHA consumes the attempt even if its repair run
failed, timed out, was skipped or was cancelled. Manually rerunning a repair
does not start another agent. A failure from the second CI workflow for the
same SHA therefore cannot produce another attempt. A more recent `main` SHA
makes an older failure stale and it is skipped.

An issue containing `ci-repair-sha:<full-sha>`, including a closed issue/PR,
or an existing repair branch also blocks another attempt. Keep ledger markers
after closing issues. Preserve Actions run history for attempts that crash
before writing a ledger. If administrators delete all matching runs, ledger
markers, PRs and branches, that deduplication evidence is gone. Actions history
retention likewise limits the record of crashes without a ledger. The workflow
uses GitHub's `queue: max` FIFO queue (up to 100 pending runs). Older commits can
be skipped when main advances; this is bounded best-effort repair, not a guarantee
to investigate every commit.

Review Actions job summaries for skipped admission decisions. Unfixable cases
produce an issue; gh-aw also reports engine/output failures through its generated
failure reporting. Missing authentication can prevent even that report, in
which case the failed Actions run is the authoritative diagnostic. There is no
automatic retry or CI-wait loop; maintainers handle blocked cases. After fixing
credentials, a new commit is required for a new automated repair opportunity.

## Editing and validation

Use GitHub CLI with the `github/gh-aw` extension, version **v1.2.2** or a reviewed
newer version. Edit the Markdown source and guard, not generated YAML:

```sh
gh aw compile ci-repair --strict --validate
node --test .github/scripts/ci-repair-admission.test.cjs
python3 scripts/validate_project.py
python3 -m unittest discover -s backend/tests -v
git diff --check
```

On a Mac with Xcode and a compatible iPhone simulator:

```sh
python3 scripts/validate_project.py --xcode
xcodebuild build -project LyricsCarPlay.xcodeproj -scheme LyricsCarPlay -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

Compilation validates and pins the generated workflow; it does not execute
Copilot, test credentials, or prove that a proposed repair works.

Initial local validation: strict compilation, 15 admission tests, 10 backend
tests, project structure validation, and the unsigned device Release build
passed. Simulator validation was attempted but failed during package resolution:
Xcode could not resolve Spotify's `v5.0.1^{commit}` revision (exit 74). Simulator
unit/UI tests did **not** run or pass. That dependency failure is reported here;
the CI-repair setup does not change the application's package pin.

The initial compiler security review covers the new restricted secret
`CI_REPAIR_APP_PRIVATE_KEY`: it is consumed only by compiler-generated official
App-token minting steps in safe-output/reporting jobs, not passed to the agent.
`COPILOT_GITHUB_TOKEN` authenticates the inference proxy. Added pinned actions
are `actions/checkout`, `actions/github-script`, `actions/create-github-app-token`,
`actions/setup-node`, `actions/upload-artifact`, `actions/download-artifact`, and
`github/gh-aw-actions/setup`; these provide checkout, admission, token minting,
runtime setup and artifact transport. No redirect changes or custom external
credential endpoints are introduced. Compiler validation verifies action pins;
this is not an independent source audit of those upstream actions. Review
future manifest changes to secrets, actions and containers before approving
them with `gh aw compile ... --approve`.
