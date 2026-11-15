'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const admit = require('./ci-repair-admission.cjs');
const sha = 'a'.repeat(40);

function fixture() {
  const context = {
    eventName: 'workflow_run', runId: 20, repo: { owner: 'owner', repo: 'repo' },
    payload: { action: 'completed', workflow_run: {
      name: 'iOS CI', conclusion: 'failure', event: 'push', head_branch: 'main',
      head_repository: { full_name: 'owner/repo' }, head_sha: sha,
    } },
  };
  const data = { current: { run_number: 10, run_attempt: 1 }, main: sha,
    runs: [], issues: [], pulls: [], branches: [] };
  const operation = name => Object.assign(() => {}, { operation: name });
  const github = { rest: {
    actions: {
      getWorkflowRun: async () => ({ data: data.current }),
      listWorkflowRuns: operation('runs'),
    },
    repos: {
      getBranch: async () => ({ data: { commit: { sha: data.main } } }),
      listBranches: operation('branches'),
    },
    issues: { listForRepo: operation('issues') },
    pulls: { list: operation('pulls') },
  } };
  github.paginate = async method => data[method.operation];
  github.paginate.iterator = async function* (method) {
    // One item per page deliberately exercises pagination rather than first page only.
    for (const item of data[method.operation]) yield { data: [item] };
  };
  return { github, context, data };
}

test('admits either exact CI name for a first failed main push', async () => {
  for (const name of ['iOS CI', 'Backend and repository checks']) {
    const f = fixture();
    f.context.payload.workflow_run.name = name;
    assert.equal((await admit(f)).eligible, true);
  }
});

for (const [field, value] of [
  ['conclusion', 'success'], ['conclusion', 'cancelled'], ['event', 'pull_request'],
  ['head_branch', 'development/mac-xcode'], ['name', 'PR checks'],
  ['head_repository', { full_name: 'attacker/repo' }], ['head_sha', 'bad-sha'],
]) {
  test(`rejects out-of-scope ${field}: ${JSON.stringify(value)}`, async () => {
    const f = fixture();
    f.context.payload.workflow_run[field] = value;
    assert.equal((await admit(f)).eligible, false);
  });
}

test('rejects non-completed events, missing payloads, and manual reruns', async () => {
  for (const change of [
    f => { f.context.payload.action = 'requested'; },
    f => { f.context.payload.workflow_run = undefined; },
    f => { f.data.current.run_attempt = 2; },
  ]) {
    const f = fixture(); change(f);
    assert.equal((await admit(f)).eligible, false);
  }
});

test('does not repair a SHA that is no longer main', async () => {
  const f = fixture(); f.data.main = 'b'.repeat(40);
  assert.equal((await admit(f)).eligible, false);
});

test('earlier failed, skipped, cancelled, or timed-out repairs consume the SHA', async () => {
  for (const conclusion of ['failure', 'skipped', 'cancelled', 'timed_out', null]) {
    const f = fixture();
    f.data.runs = [
      { id: 20, run_number: 10, display_title: `CI repair | ${sha} | failure | push` },
      { id: 19, run_number: 9, conclusion, display_title: `CI repair | ${sha} | failure | push` },
    ];
    assert.equal((await admit(f)).eligible, false);
  }
});

test('success notifications, different SHAs, and later queued runs do not consume an attempt', async () => {
  const f = fixture();
  f.data.runs = [
    { id: 1, run_number: 1, display_title: `CI repair | ${sha} | success | push` },
    { id: 2, run_number: 2, display_title: `CI repair | ${'b'.repeat(40)} | failure | push` },
    { id: 21, run_number: 11, display_title: `CI repair | ${sha} | failure | push` },
  ];
  assert.equal((await admit(f)).eligible, true);
});

test('a closed ledger/PR on a later page blocks a repeat after run retention', async () => {
  const f = fixture();
  f.data.issues = [{ body: 'unrelated' }, { state: 'closed', body: `ci-repair-sha:${sha}` }];
  assert.equal((await admit(f)).eligible, false);
});

test('an existing PR or orphaned branch blocks duplicate creation', async () => {
  for (const kind of ['pulls', 'branches']) {
    const f = fixture();
    f.data[kind] = [{ name: `ci-repair/${sha}` }];
    assert.equal((await admit(f)).eligible, false);
  }
});

test('API errors fail closed instead of admitting an uncertain attempt', async () => {
  const f = fixture();
  f.github.paginate.iterator = async function* () { throw new Error('API unavailable'); };
  await assert.rejects(admit(f), /API unavailable/);
});
