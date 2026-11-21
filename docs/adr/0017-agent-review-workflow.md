# ADR-0017: Same-repository pull requests get an advisory agent review from an inline workflow

Status: Accepted
Decided by: Shawn LoPresto, 2026-11-20 (proposed by the agent session that planned the module waves)

## Context

- The shared Actions library carries the organisation's agent review. This repository is public
  and cannot call that private library (ADR-0014), so its pull requests had no agent review.
- Coding agents write a growing share of the modules here. A second reader with fresh context
  catches standard violations the gate cannot express: a missing justification on an MS-5.3
  opening, a default that reserves capacity, a validation with no `expect_failures` run.
- A public repository must not let outside text or code steer an agent that holds a credential.

## Decision

- The `claude-review` workflow (job `review`) runs the Claude Code GitHub Action on pull requests
  whose head branch is in this repository. It reviews the diff against
  `docs/spec/module-standard.md` and posts comments that cite rule ids.
- **Advisory.** It is not a required check. `ci / gate` stays the merge check, and code-owner
  review stays the approval.
- **Read-only.** The job has `contents: read` and may write pull request comments only. Its tools
  are limited to reading the pull request and commenting. It cannot push, approve or merge.
- **Same-repository only.** The job is skipped for fork, release-please and Dependabot pull
  requests. `pull_request_target` is never used.
- **Off by default.** The job runs only when the repository variable `AGENT_ENABLED` is `true`.
  Sign-in comes from the repository secret `CLAUDE_CODE_OAUTH_TOKEN`. With neither set, the job
  is skipped and nothing fails.
- **Bounded.** 30 turns and 20 minutes per run, one run per pull request, and a new push cancels
  the run in progress.
- **Runner and pin.** GitHub-hosted (ADR-0014). The action is pinned by commit, at least two
  weeks old when chosen, like the tool pins. Dependabot bumps it.

## Consequences

- Review here differs from the library's review: a different reviewer, and no report that the
  gate reads. That difference is recorded here, as ADR-0014 recorded the runner difference.
- A pull request workflow runs from the pull request's own ref. Anyone who can push a branch to
  this repository can change the workflow in that branch and have it run with the secret. Write
  access is therefore trusted, the same trust model the library states for its consumers.
- The diff and the pull request text reach the model as untrusted input. The limits above bound
  what a steered run can do to posting comments.
- Each run draws on the account behind the token.
- The workflow has not run yet. Its first run is the test of the trigger, the tool list and the
  pinned action.

## Alternatives

- Making the library public was rejected in ADR-0014 (option b).
- No agent review here was rejected: this is the repository where agents write the most code.
- A required check was rejected until runs show the findings are reliable. A model's review
  does not block a merge on its own.
