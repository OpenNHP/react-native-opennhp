# Rebuild the native SDK

The iOS xcframework and Android `.so` files are already in the repository. Rebuild when OpenNHP publishes a release you want to ship.

## Pin a revision

`scripts/build-sdks.sh` checks out one OpenNHP revision and compiles it. It
normally tracks a release tag, not a commit on `main`, because building whatever
`main` happens to be makes a build unreproducible. The current build is a
deliberate exception: it tracks `main` because the agent-init fix the module
needs ([OpenNHP PR #1806](https://github.com/OpenNHP/opennhp/pull/1806)) is
merged on `main` but not yet in a tagged release. See the README's "Which
OpenNHP revision to ship" for the full rationale.

Current pin: `main` commit [`9c4ff38`](https://github.com/OpenNHP/opennhp/commit/9c4ff38834964294835ddcdc6c97ae76095843d0) (2026-10-23).

The script fetches `main` by default. To reproduce a build or move to a future
release, pass a ref and update `OPENNHP_REVISION`:

```sh
OPENNHP_REF=v1.0.3 ./scripts/build-sdks.sh
```

## What the script does

1. Clones `https://github.com/OpenNHP/opennhp` into `third_party/opennhp` if needed.
2. Fetches and checks out `OPENNHP_REF` (default `main`), then cleans
   `endpoints/agent` so a re-run starts from a pristine tree.
3. Applies `scripts/opennhp-agent-sdk.patch`. The agent-init fix (PR #1806) is
   already on `main`, so it is no longer applied as a local patch. The SDK patch
   removes an unused `import "C"` so `gomobile` can compile the iOS package,
   keeps registration in `endpoints/agent/sdk_register.go` with thin iOS and
   Android wrappers, and adds `NhpAgentInitWithKey` so the agent can start from a
   key held by the platform secure store instead of `config.toml`. Registration
   does not call `ReinitWithKey` on an agent that is already running.
4. Selects `golang.org/x/mobile` at `v0.0.0-20261011034528-197770444867`. The revision shipped in the OpenNHP module file is too old for current `gomobile`.
5. Builds `libnhpagent.so` for `arm64-v8a`, `armeabi-v7a`, `x86`, and `x86_64` with the Android NDK (API 21 clang).
6. Builds `nhpagent.xcframework` with `gomobile bind -target ios -iosversion=15.1`.
7. Copies the binaries into `android/src/main/jniLibs` and `ios/Frameworks`.
8. Sets the framework `MinimumOSVersion` to `15.1`. Current `gomobile` writes `100.0` there as a Swift Package Manager workaround, which CocoaPods will not accept.
9. Rewrites the iOS build info so the framework does not contain the build machine's home directory. Go records the local `replace` path there even when `-trimpath` is set. Android builds use `-trimpath` and do not contain that path.

`third_party/` and `build/` are gitignored. Commit the copied binaries and `OPENNHP_REVISION`.

## Tools

- Go (the current binaries were built with Go 1.27.3; OpenNHP's module asks for Go 1.26 or newer)
- Xcode, with `xcode-select` pointing at `Xcode.app`
- Android NDK. The script uses `ANDROID_NDK_HOME`, or the newest NDK under `~/Library/Android/sdk/ndk` on macOS. The current binaries used NDK `28.0.13004108`.

```sh
export ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/28.0.13004108"
./scripts/build-sdks.sh
```

The script installs `gomobile` and `gobind` into `$(go env GOPATH)/bin` when they are missing.

## Output

| File | Platform |
| --- | --- |
| `ios/Frameworks/nhpagent.xcframework` | iOS device and simulator |
| `android/src/main/jniLibs/arm64-v8a/libnhpagent.so` | Android 64-bit phones and arm64 emulators |
| `android/src/main/jniLibs/armeabi-v7a/libnhpagent.so` | Android 32-bit phones |
| `android/src/main/jniLibs/x86_64/libnhpagent.so` | Android x86_64 emulators |
| `android/src/main/jniLibs/x86/libnhpagent.so` | Android x86 emulators |

The iOS simulator binary is about 81 MB. GitHub warns above 50 MB and rejects a file above 100 MB. The arm64 device slice and each `.so` are under the warning threshold.
