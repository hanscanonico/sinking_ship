export const meta = {
	name: 'improve',
	description:
		'Implement→adversarial-review pipeline: one PR per task via Opus subagents, one retry at high effort on a red gate or a reject',
	whenToUse:
		'Delegated implementation of scouted task specs, ordered by after: and capped by concurrency; used by the /orchestrate skill',
	phases: [
		{ title: 'Implement', detail: 'one implementer per task in its own worktree, medium effort' },
		{ title: 'Review', detail: 'adversarial review + small fixes in the same worktree, high effort' },
		{ title: 'Retry', detail: 'the one high-effort implementer retry, then a review of what changed' },
	],
}

// args: { tasks: [{ slug, task, reviewNote?, after? }, ...], label?, concurrency?, stagger_seconds?,
//         trailers?, footer? }
//   slug            names the worktree (improve-<slug>) and branch (improve/<slug>)
//   task            the full task brief (may point at a spec file the orchestrator wrote)
//   reviewNote      extra context for the reviewer (what to independently verify)
//   after           slugs of tasks in this run this one builds on: it starts only once every
//                   one of them ends with verdict approve, and branches from their branches;
//                   any other ending skips it. Unknown or cyclic slugs throw before any agent.
//   label           names the batch ("water batch 6"): every agent label reads
//                   impl:<label>/<slug>, and the narrator line and the returned summary carry it
//                   (meta must stay a pure literal, so the phase titles cannot)
//   concurrency     how many implementers + reviewers run at once (default 3)
//   stagger_seconds the gap between any two agent starts (default 60), so make import and the
//                   gate do not all hit the shared machine together
//   trailers        optional commit-trailer block; empty means no trailer at all
//   footer          PR-body footer for this session (generated-with + session link)
//
// Every agent runs on the latest Opus available: the `opus` alias, never Fable, never a
// dated Opus id. Effort lives on the agent definitions (implementer medium, reviewer
// high); the one per-call override here is the retry, which runs the implementer at high.
//
// Returns { label, summary, results }. Each result: { slug, impl, review, retry, verdict } —
// retry is null or a second { impl, review }; a skipped task carries { skipped: true, reason }
// instead. verdict reads the last attempt: approve | reject | verify_failed | gate_timed_out |
// abandoned | unreviewed | no_result | skipped | error.
// impl.local_gate is the implementer's make verify-changed (completed | timed_out | failed);
// anything but completed is the red gate the retry answers. impl.ci_green is what it saw on
// the PR head when it reported, and impl.verify_pass is derived here as local_gate ===
// 'completed' for older readers. No verdict is a merge: the orchestrator checks CI's full
// make verify on the PR head itself.
// Some harness routes deliver args as a JSON string rather than a parsed value.
const raw = typeof args === 'string' ? JSON.parse(args) : args
const input = raw && raw.tasks ? raw : { tasks: raw }
if (!Array.isArray(input.tasks) || input.tasks.length === 0) {
	throw new Error('improve: pass args = { tasks: [{ slug, task }, ...] }')
}

// Validate the whole run before any agent starts: unique slugs, known `after` slugs, no cycle.
const bySlug = new Map()
for (const t of input.tasks) {
	if (!t || typeof t.slug !== 'string' || !t.slug || typeof t.task !== 'string') {
		throw new Error('improve: every task needs a slug and a task string')
	}
	if (bySlug.has(t.slug)) throw new Error(`improve: duplicate slug ${t.slug}`)
	bySlug.set(t.slug, t)
}
const afterOf = (t) => {
	if (t.after === undefined || t.after === null) return []
	if (!Array.isArray(t.after)) throw new Error(`improve: ${t.slug}.after must be an array of slugs`)
	return t.after
}
for (const t of input.tasks) {
	for (const dep of afterOf(t)) {
		if (dep === t.slug) throw new Error(`improve: ${t.slug} is after itself`)
		if (!bySlug.has(dep)) throw new Error(`improve: ${t.slug} is after unknown slug ${dep}`)
	}
}
{
	const state = new Map() // slug → 'visiting' | 'done'
	const visit = (slug, path) => {
		if (state.get(slug) === 'done') return
		if (state.get(slug) === 'visiting') {
			throw new Error(`improve: cyclic after: ${path.concat(slug).join(' → ')}`)
		}
		state.set(slug, 'visiting')
		for (const dep of afterOf(bySlug.get(slug))) visit(dep, path.concat(slug))
		state.set(slug, 'done')
	}
	for (const t of input.tasks) visit(t.slug, [])
}

const label = typeof input.label === 'string' ? input.label.trim() : ''
const concurrency = input.concurrency === undefined ? 3 : Number(input.concurrency)
if (!Number.isInteger(concurrency) || concurrency < 1) {
	throw new Error('improve: concurrency must be an integer of at least 1')
}
const staggerSeconds = input.stagger_seconds === undefined ? 60 : Number(input.stagger_seconds)
if (!Number.isFinite(staggerSeconds) || staggerSeconds < 0) {
	throw new Error('improve: stagger_seconds must be a number of at least 0')
}

const IMPL = {
	type: 'object',
	required: ['pr_url', 'branch', 'worktree', 'local_gate', 'ci_green', 'summary'],
	properties: {
		pr_url: { type: 'string', description: 'Empty when no PR was opened' },
		branch: { type: 'string' },
		worktree: { type: 'string' },
		local_gate: {
			type: 'string',
			enum: ['completed', 'timed_out', 'failed'],
			description:
				'make verify-changed plus any area gate in the worktree: completed = it ran to its end and passed; failed = it ran to its end and something was red; timed_out = it had not ended when you reported (slots held, machine loaded). Never completed for a gate you did not see end. Not read when abandoned.',
		},
		ci_green: {
			type: 'boolean',
			description:
				"True only when you saw CI's verify check concluded success on the PR head you last pushed; false when red, still running, or not observed",
		},
		head_sha: { type: 'string', description: 'The commit the PR head points at when you report' },
		summary: { type: 'string' },
		notes: { type: 'string' },
		abandoned: {
			type: 'boolean',
			description: 'True when the task was judged wrong or already done and no change was made',
		},
	},
}
const REVIEW = {
	type: 'object',
	required: ['verdict', 'reasons', 'head_sha'],
	properties: {
		verdict: { type: 'string', enum: ['approve', 'reject'] },
		reasons: { type: 'string' },
		fixed: { type: 'string' },
		head_sha: { type: 'string', description: 'The PR head commit you reviewed, after any fix you pushed' },
	},
}

const trailers = input.trailers || ''
const footer = input.footer || ''

const trailerNote = trailers
	? 'Commit trailers to use (end the commit message with these lines):\n\n' + trailers
	: 'Do not add any Co-Authored-By, Generated-with or session trailer to commits or PR bodies — the user is the sole author.'
const footerNote = footer ? '\n\nPR body footer (end the PR body with these lines):\n\n' + footer : ''
const reviewTrailerNote = trailers
	? '\n\nIf you commit fixes, end the commit message with:\n\n' + trailers
	: '\n\nDo not add any Co-Authored-By or attribution trailer to commits.'

const agentLabel = (kind, slug) => `${kind}:${label ? label + '/' : ''}${slug}`

// The approved tasks this one builds on: [{ slug, branch, pr_url }], in `after` order.
const baseNote = (bases) => {
	if (bases.length === 0) return ''
	const [first, ...rest] = bases
	const list = bases.map((b) => `${b.slug} (branch ${b.branch}, PR ${b.pr_url || 'none'})`).join('; ')
	const fetches = bases.map((b) => b.branch).join(' ')
	return (
		`\n\nBUILDS ON: ${list} — approved in review, possibly not merged yet. ` +
		`In setup step 1 also fetch them (\`git -C /Users/hanscanonico/Projets/sinking_ship fetch origin ${fetches}\`) ` +
		`and in step 2 branch from \`origin/${first.branch}\` instead of \`origin/main\`` +
		(rest.length
			? `, then \`git merge --no-edit ${rest.map((b) => 'origin/' + b.branch).join(' ')}\` before you edit`
			: '') +
		'. Open the PR against main as usual: its diff shows those commits too until they merge, and the orchestrator will `gh pr update-branch` yours after they do.'
	)
}

const implBrief = (t, bases) => `Task slug: ${t.slug}\n\n${t.task}${baseNote(bases)}\n\n${trailerNote}${footerNote}`

const retryBrief = (t, impl, review) => {
	const worktree = (impl && impl.worktree) || 'the one your setup step names for this slug'
	const branch = (impl && impl.branch) || `improve/${t.slug}`
	const pr = impl && impl.pr_url ? `PR ${impl.pr_url}` : 'no PR yet'
	const why = review
		? `The first attempt was REJECTED in review. Reasons:\n${review.reasons}` +
			(review.fixed ? `\n\nThe reviewer already fixed and pushed:\n${review.fixed}` : '')
		: `The first attempt did not get its gate green (local_gate: ${(impl && impl.local_gate) || 'unknown'}).` +
			(impl && impl.summary ? `\nWhat it did:\n${impl.summary}` : '') +
			(impl && impl.notes ? `\nIts notes:\n${impl.notes}` : '')
	return (
		`Task slug: ${t.slug}\n\nSECOND ATTEMPT. A first attempt exists in worktree ${worktree} on branch ${branch} (${pr}) — work there, do not recreate the worktree.\n\n${why}\n\n` +
		`Address every reason above, get the gate green, commit and push to the same branch (open the PR only if none exists).\n\n${t.task}\n\n${trailerNote}${footerNote}`
	)
}

const reviewBrief = (t, impl, bases, prior, priorSha) =>
	`Review the PR in worktree ${impl.worktree} (branch ${impl.branch}, PR ${impl.pr_url}).\n\nThe task it implements:\n${t.task}\n` +
	(t.reviewNote ? '\nWhat to verify independently: ' + t.reviewNote : '') +
	(bases.length
		? `\n\nThis branch builds on ${bases.map((b) => b.branch).join(', ')} (approved, possibly unmerged): review its own commits — \`git diff origin/${bases[bases.length - 1].branch}...HEAD\` after a fetch — not theirs.`
		: '') +
	(prior
		? `\n\nThis is a second attempt. The first review's verdict was ${prior.verdict}, for:\n${prior.reasons}\n` +
			`The first review saw head ${priorSha || 'unknown (read it from `gh pr view --json commits`)'}. ` +
			'Check each reason was addressed and focus the read on what changed since that commit ' +
			`(\`git diff ${priorSha || '<that sha>'}..HEAD\`), but still run every gate check you would run on a fresh PR — ` +
			'the new and changed tests, make check lint format-check, the captures for a visual change.'
		: '') +
	reviewTrailerNote

const MODEL = 'opus' // the alias tracks the newest Opus release

// The concurrency cap: a FIFO semaphore every agent start goes through, and a start chain
// that keeps any two starts stagger_seconds apart. The runtime does not promise setTimeout;
// without it the stagger degrades to ordering starts, and the cap still holds.
const sleep = (ms) =>
	ms > 0 && typeof setTimeout === 'function' ? new Promise((r) => setTimeout(r, ms)) : Promise.resolve()
let active = 0
const waiting = []
const acquire = () => {
	if (active < concurrency) {
		active++
		return Promise.resolve()
	}
	return new Promise((r) => waiting.push(r))
}
const release = () => {
	const next = waiting.shift()
	if (next) next()
	else active--
}
let startChain = Promise.resolve()
const startGap = () => {
	const mine = startChain
	startChain = mine.then(() => sleep(staggerSeconds * 1000))
	return mine
}
const run = async (prompt, opts) => {
	await acquire()
	try {
		await startGap()
		return await agent(prompt, { ...opts, model: MODEL })
	} finally {
		release()
	}
}

// local_gate is the gate signal; verify_pass is derived from it so older readers still work.
const withDerived = (impl) => (impl ? { ...impl, verify_pass: impl.local_gate === 'completed' } : impl)
const runImpl = (prompt, opts) =>
	run(prompt, { ...opts, agentType: 'implementer', schema: IMPL }).then(withDerived)

const reviewable = (impl) => Boolean(impl && impl.local_gate === 'completed' && !impl.abandoned)

const review = (t, impl, bases, prior, priorSha, phaseName, kind) =>
	run(reviewBrief(t, impl, bases, prior, priorSha), {
		label: agentLabel(kind, t.slug),
		phase: phaseName,
		agentType: 'reviewer',
		schema: REVIEW,
	})

// One retry, never more. A null impl means the user skipped the agent or it died on a
// terminal API error — not something a second attempt should override.
const needsRetry = (impl, rev) => {
	if (!impl || impl.abandoned) return false
	if (impl.local_gate !== 'completed') return true
	return Boolean(rev && rev.verdict === 'reject')
}

const verdictOf = (r) => {
	const last = r.retry || r
	if (!last.impl) return 'no_result'
	if (last.impl.abandoned) return 'abandoned'
	if (last.impl.local_gate === 'timed_out') return 'gate_timed_out'
	if (last.impl.local_gate !== 'completed') return 'verify_failed'
	if (!last.review) return 'unreviewed'
	return last.review.verdict
}

const lastImpl = (r) => (r.retry && r.retry.impl) || r.impl

const attempt = async (t, bases) => {
	const impl = await runImpl(implBrief(t, bases), { label: agentLabel('impl', t.slug), phase: 'Implement' })
	const rev = reviewable(impl) ? await review(t, impl, bases, null, null, 'Review', 'review') : null
	const first = { slug: t.slug, impl, review: rev, retry: null }
	if (!needsRetry(impl, rev)) return first
	log(`${agentLabel('impl', t.slug)}: ${rev ? 'rejected' : 'gate ' + impl.local_gate} — retrying once at high effort`)
	const impl2 = await runImpl(retryBrief(t, impl, rev), {
		label: agentLabel('retry', t.slug),
		phase: 'Retry',
		effort: 'high',
	})
	const priorSha = (rev && rev.head_sha) || impl.head_sha || ''
	const rev2 = reviewable(impl2) ? await review(t, impl2, bases, rev, priorSha, 'Retry', 're-review') : null
	return { ...first, retry: { impl: impl2, review: rev2 } }
}

// The frontier: a task with no `after` starts at once (behind the semaphore); one with
// `after` starts when every named task has ended, and only if each ended approve.
const ended = new Map() // slug → Promise<result>
const launch = async (t) => {
	const deps = await Promise.all(afterOf(t).map((s) => start(bySlug.get(s))))
	const blocker = deps.find((d) => d.verdict !== 'approve')
	if (blocker) {
		const reason = `after:${blocker.slug} ${blocker.verdict}`
		log(`${agentLabel('impl', t.slug)}: skipped — ${reason}`)
		return { slug: t.slug, skipped: true, reason, impl: null, review: null, retry: null, verdict: 'skipped' }
	}
	const bases = deps.map((d) => {
		const i = lastImpl(d)
		return { slug: d.slug, branch: i.branch || `improve/${d.slug}`, pr_url: i.pr_url || '' }
	})
	try {
		const r = await attempt(t, bases)
		return { ...r, verdict: verdictOf(r) }
	} catch (e) {
		return {
			slug: t.slug,
			error: String((e && e.message) || e),
			impl: null,
			review: null,
			retry: null,
			verdict: 'error',
		}
	}
}
const start = (t) => {
	if (!ended.has(t.slug)) ended.set(t.slug, launch(t))
	return ended.get(t.slug)
}

log(
	`${label || 'improve'}: ${input.tasks.length} task(s), ${concurrency} agent(s) at once, starts ${staggerSeconds}s apart`
)
phase('Implement')
const results = await Promise.all(input.tasks.map(start))

const summary =
	`${label || 'improve'}: ` +
	results.map((r) => `${r.slug} ${r.verdict}${r.reason ? ` (${r.reason})` : ''}`).join(', ')
log(summary)

return { label, summary, results }
