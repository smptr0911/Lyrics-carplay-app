'use strict';

// Read-only admission. Workflow-wide concurrency serializes this check through
// safe-output completion. Fail closed on every API error (do not catch errors).
module.exports = async function admit({ github, context }) {
  const run = context.payload.workflow_run;
  const repo = context.repo;
  const fullName = `${repo.owner}/${repo.repo}`;
  const deny = reason => ({ eligible: false, reason });
  if (context.eventName !== 'workflow_run' || context.payload.action !== 'completed'
      || run?.conclusion !== 'failure' || run.event !== 'push'
      || run.head_branch !== 'main' || run.head_repository?.full_name !== fullName
      || !['Backend and repository checks', 'iOS CI'].includes(run.name)
      || !/^[a-f0-9]{40}$/.test(run.head_sha)) {
    return deny('Not a failed, same-repository push CI run on main.');
  }
  const { data: current } = await github.rest.actions.getWorkflowRun({ ...repo, run_id: context.runId });
  if (current.run_attempt !== 1) return deny('This repair run has already been attempted.');
  const { data: main } = await github.rest.repos.getBranch({ ...repo, branch: 'main' });
  if (main.commit.sha !== run.head_sha) return deny('Main has advanced; no repair of a stale commit.');
  const title = `CI repair | ${run.head_sha} | failure | push`;
  // Do not filter by head_sha: repair runs execute on the default branch SHA.
  for await (const page of github.paginate.iterator(github.rest.actions.listWorkflowRuns, {
    ...repo, workflow_id: 'ci-repair.lock.yml', per_page: 100,
  })) {
    if (page.data.some(previous => previous.id !== context.runId
        && previous.run_number < current.run_number && previous.display_title === title)) {
      return deny('An earlier repair run already consumed this commit, regardless of its outcome.');
    }
  }
  // These resources outlive Actions run retention, including closed issues/PRs.
  const marker = `ci-repair-sha:${run.head_sha}`;
  for await (const page of github.paginate.iterator(github.rest.issues.listForRepo, {
    ...repo, state: 'all', per_page: 100,
  })) {
    if (page.data.some(item => item.body?.includes(marker))) return deny('This commit has an attempt ledger or PR.');
  }
  const branch = `ci-repair/${run.head_sha}`;
  const pulls = await github.paginate(github.rest.pulls.list, {
    ...repo, state: 'all', head: `${repo.owner}:${branch}`, per_page: 100,
  });
  if (pulls.length) return deny('A repair PR already exists, including closed or merged PRs.');
  const branches = await github.paginate(github.rest.repos.listBranches, { ...repo, per_page: 100 });
  if (branches.some(item => item.name === branch)) return deny('A repair branch already exists.');
  return { eligible: true, reason: `One repair attempt admitted for ${run.head_sha}.` };
};
