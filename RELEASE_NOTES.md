# Release notes — move the SDK build to OpenNHP `main`

Date: 2026-10-25
OpenNHP pin: `main` commit `9c4ff38834964294835ddcdc6c97ae76095843d0` (2026-10-23)

## What changed in this repo

- `scripts/build-sdks.sh` now builds from OpenNHP `main` instead of the `v1.0.2`
  tag. It fetches `main` by default and honours `OPENNHP_REF=<tag|branch|commit>`
  for a pinned or future build. It also starts from a pristine tree
  (`git clean -fd endpoints/agent`) so re-runs do not trip over the new
  untracked file the patch adds.
- Removed `scripts/opennhp-agent-init-fix.patch`. That fix is OpenNHP PR #1806,
  now merged on `main`, so the build no longer needs a local copy.
- `scripts/opennhp-agent-sdk.patch` was regenerated against `main` and reworked
  (see below). It now touches **only** iOS/Android/SDK files:
  `endpoints/agent/iossdk/export.go`, `endpoints/agent/main/export.go`, and the
  new `endpoints/agent/sdk_register.go`.
- Rebuilt the native libraries from `main` + the patch: all four Android ABIs
  (`android/src/main/jniLibs/*/libnhpagent.so`) and the iOS
  `nhpagent.xcframework`. Verified the registration symbols are exported
  (`nhp_agent_init_with_key` / `_request_otp` / `_register` on Android;
  `IossdkNhpAgentInitWithKey` / `RequestOtp` / `Register` on iOS).
- Updated `OPENNHP_REVISION` and the README revision/changelog sections.

## Review feedback from the closed PRs (#1807 / #1808)

The feature PRs were closed with a `CHANGES_REQUESTED` review. Status against the
current patch:

Must-fix (already addressed in the patch, carried over from this repo's prior work):

- **Re-keying a running agent / data race** — `prepareRegistration` refuses to
  re-key a running agent; it only reuses a running agent whose key and cipher
  scheme already match, and otherwise starts a short-lived throwaway agent.
- **`InstallRegistrationKey` skipped the cipher update on a key match** — it now
  also compares the cipher scheme before the early return.
- **`RegisterDevice` with an empty key could register a fresh key** — it now
  returns `ErrInvalidInput` ("privateKey is required") unless a running agent
  already holds that key.

Addressed in this pass (in scope):

- **Logger leak when `Start` fails** — `StartAllowingMissingConfig` now closes
  the agent logger on the `Start` error path.
- **Private key returned in the registration JSON** — handled at the React
  Native bridge, which strips `privateKey` from the JSON and stores it in the
  iOS Keychain / Android Keystore-wrapped store before returning to JavaScript
  (`OpenNhpRegistrationJSON` in `ios/OpenNhp.m`). The native export still returns
  the key because the secure-store layer needs it; it never reaches JavaScript.

## Recommended changes OUTSIDE the iOS/Android scope — for your review

These were intentionally **not** applied, because they touch shared OpenNHP code
or are optional review suggestions. Investigate before upstreaming.

1. **`nhp/log/globalLog.go` — add a public `SetLevel(level int)`** (shared log
   package, not iOS/Android).
   - Why it came up: when `config.toml` is missing, `loadBaseConfig` applies the
     empty config's log level (silent, `0`) over the level passed to `Start`
     (`endpoints/agent/config.go:273`). The registration bootstrap needs the
     requested level restored.
   - What this repo did instead (in scope): `StartAllowingMissingConfig` restores
     the level through the agent's own logger
     (`instance.log.SetLogLevel(logLevel)`), using the already-exported
     `(*log.Logger).SetLogLevel`. No change to `nhp/log`.
   - Recommendation: if the registration flow is upstreamed, a small
     `log.SetLevel` helper on the shared package may be the cleaner public API.
     That is a core-package change and is your call.

2. **`endpoints/agent/sdk_register.go` placement.** This new file lives in the
   shared `endpoints/agent` package (used by `nhp-agentd` too), not under a
   mobile-only directory, even though only the iOS/Android exports call it. It
   adds exported symbols to a shared package. Consider whether upstream would
   want it namespaced or guarded.

3. **`gAgentInstance` synchronization** (review suggestion). The package-global
   agent handle in the export files has no mutex, so concurrent init/close/
   registration calls can race and leak an agent. This is a pre-existing
   condition in the upstream export files (it predates the registration patch).
   A `sync.Mutex` around the lifecycle functions would fix it, but it modifies
   upstream functions beyond the registration feature, so it is left for your
   review.

4. **`config.toml` can override an injected key's cipher scheme** (review
   suggestion). When a `config.toml` is present, its `DefaultCipherScheme` can
   differ from the cipher of the key installed via `InstallRegistrationKey`.
   The registration flow targets the no-config bootstrap case, so this is not
   hit in normal use, but a deeper reconciliation in the agent package may be
   warranted.

5. **Unit tests + `-race`** (review request). The reviewer asked for tests under
   `go test ./agent/...`, including a `-race` run. A `sdk_register_test.go` would
   live in the in-scope `endpoints/agent` package; it was not added here. Worth
   adding before the next upstream attempt.
