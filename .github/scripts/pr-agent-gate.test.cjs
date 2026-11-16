'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');

// Exercise the exact deterministic script embedded in the authored workflow.
const source = readFileSync(join(__dirname, '../workflows/pr-automation.yml'), 'utf8');
const block = source.match(/            \/\/ PR_GATE_START[^\n]*\n([\s\S]*?)            \/\/ PR_GATE_END/);
assert.ok(block, 'PR admission script must remain identifiable');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const gate = new AsyncFunction('github', 'context', 'core', block[1].replace(/^            /gm, ''));
const sha = 'a'.repeat(40);

test('caller run-name agrees with the persisted attempt key', () => {
  assert.ok(source.includes('run-name: "PR agent | ${{ github.event.pull_request.number }} | ${{ github.event.pull_request.head.sha }}"'));
});

test('installation can keep PR inference paused until live testing is approved', () => {
  assert.ok(source.includes("vars.PR_AGENT_ENABLED == 'true' &&"));
});

test('publication has no GitHub App credential dependency', () => {
  for (const name of ['pr-agent.md', 'pr-agent.lock.yml', 'ci-repair.md', 'ci-repair.lock.yml', 'pr-automation.yml']) {
    const text = readFileSync(join(__dirname, '../workflows', name), 'utf8');
    assert.ok(!text.includes('CI_REPAIR_APP_'), `${name} must use scoped GITHUB_TOKEN publication`);
  }
});

test('safe dispatch is restricted to the three validation workflows and exact repair refs', () => {
  for (const name of ['pr-agent.md', 'ci-repair.md']) {
    const text = readFileSync(join(__dirname, '../workflows', name), 'utf8');
    const dispatch = text.match(/  dispatch-workflow:\n([\s\S]*?)(?=\n  [a-z-]+:)/);
    assert.ok(dispatch, `${name} must explicitly validate published candidates`);
    assert.ok(dispatch[1].includes('workflows: [backend-ci, ios-ci, pr-checks]'));
    assert.ok(dispatch[1].includes('max: 3'));
    assert.ok(dispatch[1].includes('allowed-refs: ["'));
    assert.ok(!dispatch[1].includes('*'), 'ref scope must be exact, not a branch wildcard');
  }
});

test('caller permits every scope required by the generated reusable jobs', () => {
  const lock = readFileSync(join(__dirname, '../workflows/pr-agent.lock.yml'), 'utf8');
  const caller = source.slice(source.indexOf('  review_and_repair:'));
  const scopeLevels = { none: 0, read: 1, write: 2 };
  const callerScopes = Object.fromEntries([...caller.matchAll(/^      ([a-z-]+): (none|read|write)\b/gm)]
    .map(match => [match[1], scopeLevels[match[2]]]));
  const blocks = [...lock.matchAll(/^    permissions:\n((?:      [^\n]+\n)+)/gm)];
  assert.ok(blocks.length > 0, 'generated jobs must declare permissions');
  for (const block of blocks) {
    for (const match of block[1].matchAll(/^      ([a-z-]+): (none|read|write)\b/gm)) {
      assert.ok((callerScopes[match[1]] || 0) >= scopeLevels[match[2]], `caller cannot narrow ${match[1]} below ${match[2]}`);
    }
  }
});

function fixture() {
  const p = { number: 7, state: 'open', base: { ref: 'main', repo: { full_name: 'owner/repo' } },
    head: { sha, ref: 'feature/work', repo: { full_name: 'owner/repo' } } };
  const context = { eventName: 'pull_request', runId: 20,
    repo: { owner: 'owner', repo: 'repo' }, payload: { pull_request: p } };
  const data = { current: { run_number: 10, run_attempt: 1, workflow_id: 42 },
    latest: structuredClone(p), runs: [], reviews: [] };
  const operation = name => Object.assign(() => {}, { operation: name });
  const github = { rest: {
    actions: { getWorkflowRun: async () => ({ data: data.current }), listWorkflowRuns: operation('runs') },
    pulls: { get: async () => ({ data: data.latest }), listReviews: operation('reviews') },
  }, paginate: { iterator: async function* (method) {
    for (const item of data[method.operation]) yield { data: [item] };
  } } };
  const outputs = {};
  const summary = { addHeading() { return this; }, addRaw() { return this; }, async write() {} };
  const core = { summary, setOutput: (name, value) => { outputs[name] = value; } };
  return { context, data, github, core, outputs, run: () => gate(github, context, core) };
}

test('admits a current same-repository PR', async () => {
  const f = fixture(); await f.run(); assert.equal(f.outputs.eligible, 'true');
});

for (const [name, mutate] of [
  ['fork', f => { f.context.payload.pull_request.head.repo.full_name = 'attacker/repo'; }],
  ['deleted fork', f => { f.context.payload.pull_request.head.repo = null; }],
  ['other base', f => { f.context.payload.pull_request.base.ref = 'release'; }],
  ['other base repository', f => { f.context.payload.pull_request.base.repo.full_name = 'other/repo'; }],
  ['closed PR', f => { f.context.payload.pull_request.state = 'closed'; }],
  ['invalid SHA', f => { f.context.payload.pull_request.head.sha = 'bad'; }],
  ['generated PR fix', f => { f.context.payload.pull_request.head.ref = 'pr-fix/7-abc'; }],
  ['generated CI fix', f => { f.context.payload.pull_request.head.ref = 'ci-repair/abc'; }],
  ['rerun', f => { f.data.current.run_attempt = 2; }],
  ['stale SHA', f => { f.data.latest.head.sha = 'b'.repeat(40); }],
  ['changed branch', f => { f.data.latest.head.ref = 'another'; }],
  ['retargeted PR', f => { f.data.latest.base.ref = 'release'; }],
  ['closed while queued', f => { f.data.latest.state = 'closed'; }],
]) {
  test(`rejects ${name}`, async () => {
    const f = fixture(); mutate(f); await f.run(); assert.equal(f.outputs.eligible, 'false');
  });
}

test('rejects an earlier consumed attempt on a later history page', async () => {
  const f = fixture();
  f.data.runs = [{ id: 20, run_number: 10 },
    { id: 19, run_number: 9, conclusion: 'failure', display_title: `PR agent | 7 | ${sha}` }];
  await f.run(); assert.equal(f.outputs.eligible, 'false');
});

test('ignores newer queued attempts and unrelated revisions', async () => {
  const f = fixture();
  f.data.runs = [
    { id: 21, run_number: 11, display_title: `PR agent | 7 | ${sha}` },
    { id: 1, run_number: 1, display_title: `PR agent | 7 | ${'b'.repeat(40)}` },
  ];
  await f.run(); assert.equal(f.outputs.eligible, 'true');
});

test('a completed review remains a durable duplicate marker', async () => {
  const f = fixture();
  f.data.reviews = [{ body: 'unrelated' }, { user: { type: 'Bot' },
    body: `pr-agent-sha:${sha}\n<!-- gh-aw-workflow-id: pr-agent -->` }];
  await f.run(); assert.equal(f.outputs.eligible, 'false');
});

test('a forged marker from a human or unrelated bot does not suppress review', async () => {
  const f = fixture();
  f.data.reviews = [
    { user: { type: 'User' }, body: `pr-agent-sha:${sha}\n<!-- gh-aw-workflow-id: pr-agent -->` },
    { user: { type: 'Bot' }, body: `pr-agent-sha:${sha}` },
  ];
  await f.run(); assert.equal(f.outputs.eligible, 'true');
});

test('API errors fail closed before any eligible output', async () => {
  const f = fixture();
  f.github.rest.pulls.get = async () => { throw new Error('API unavailable'); };
  await assert.rejects(f.run(), /API unavailable/);
  assert.notEqual(f.outputs.eligible, 'true');
});
