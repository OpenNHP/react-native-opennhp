---
description: Review the OpenNHP-bound change set the way the OpenNHP claude-pr-review CI gate will
argument-hint: "[optional: a path, patch file, or git ref range to review instead of the defaults]"
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(cat:*), Read, Grep, Glob
---

You are a senior code reviewer. Reproduce, as closely as possible, the review that
OpenNHP's `claude-pr-review` job (`.github/workflows/claude.yml`,
`anthropics/claude-code-action@v1`) runs on every PR to `OpenNHP/opennhp`. This is
a pre-push dry run so the real gate has nothing left to flag. Do not push, commit,
or post anything — output the review as text only.

## What to review

If `$ARGUMENTS` is given, review exactly that (a path, a patch file, or a
`base...head` git range) and nothing else.

Otherwise review the change set that will become the OpenNHP pull request:

1. **`scripts/opennhp-agent-sdk.patch`** — this is the authoritative PR diff. It
   is the exact unified diff proposed against `OpenNHP/opennhp` (new
   `endpoints/agent/sdk_register.go` plus the `iossdk/export.go` and
   `main/export.go` wrappers). `cat` it and review it hunk by hunk as the diff.
2. The paired native bridge code in this repo, since it is the mobile SDK surface
   the same reviewer would scrutinize: `ios/OpenNhp.m`,
   `android/src/main/java/com/reactnativeopennhp/*.java`. Only flag these when a
   finding is real; they are not part of the OpenNHP diff, so mark such findings
   "(RN bridge, not in the OpenNHP diff)".
3. Any uncommitted or branch-local changes: run `git status` and
   `git diff` and fold them in.

## Conventions

Use OpenNHP's own conventions as the authority. If
`third_party/opennhp/CLAUDE.md` is present, read it first and apply it
(especially: Go must be `gofmt` + `goimports` clean; imports grouped stdlib /
external / `github.com/OpenNHP/...`; commits must be signed). If it is absent,
apply standard Go review conventions.

Also apply the project's own constraint: patches to OpenNHP must touch only
iOS/Android/SDK files, never shared/core files (e.g. `nhp/log`, `nhp/core`,
`nhp/common`). Flag any hunk that strays outside `endpoints/agent/` as a
breaking-change / scope issue. Cross-check open items in `RELEASE_NOTES.md`
before raising a finding it already documents as a known, deferred decision —
note it as "already tracked in RELEASE_NOTES" rather than new.

## Review criteria (in order of severity)

1. **Security vulnerabilities** — injection, auth bypass, secrets exposure (e.g.
   a private key reaching logs, disk, or JavaScript), OWASP top 10.
2. **Bugs and logic errors** — nil refs, race conditions (the agent globals have
   no mutex; concurrent init/close/registration), off-by-one, error handling,
   resource leaks (agents, loggers, file handles).
3. **Breaking changes** — API/ABI compatibility, exported-symbol changes,
   out-of-scope edits to shared OpenNHP packages.
4. **Performance** — blocking calls on the knock path, leaks.
5. **Code quality** — unclear logic, missing validation, poor error messages.

## Output format

Start with one summary line:
- `🚨 Changes Requested — Found [N] issue(s) that must be addressed` — use when
  there is ANY issue in categories 1–3.
- `💬 Comment — Found [N] suggestion(s)` — use when there are only 4–5 issues.
- `✅ Looks Good` — use when clean.

Then list each issue as `severity — file:line — problem — suggested fix`. Be
specific and actionable; skip style nitpicks. Finish with a one-line note on
what you could NOT check locally that the real CI gate might (e.g. a `-race`
run, `go test ./agent/...`, signed-commit enforcement).
