# Rebuild the native SDK

The iOS xcframework and Android `.so` files are already in the repository. Rebuild when OpenNHP publishes a release you want to ship.

## Pin a release

`scripts/build-sdks.sh` checks out one release tag and compiles it. The pin is that tag, not a commit on `main`. Building whatever `main` happens to be today makes each release unreproducible.

Current pin: [v1.0.2](https://github.com/OpenNHP/opennhp/releases/tag/v1.0.2) (`1f1daad0a02e`, 2026-09-11). This is the latest OpenNHP release.

To move the pin, set `RELEASE` in `scripts/build-sdks.sh` to the new tag, run the script, and update `OPENNHP_REVISION`.

## What the script does

1. Clones `https://github.com/OpenNHP/opennhp` into `third_party/opennhp` if needed.
2. Checks out `RELEASE`.
3. Applies `scripts/opennhp-agent-sdk.patch`. That patch removes an unused `import "C"` so `gomobile` can compile the iOS package. Registration lives once in `endpoints/agent/sdk_register.go`. The iOS and Android export files are thin wrappers around it. The patch also adds `NhpAgentInitWithKey` so the agent can start from a key held by the platform secure store instead of `config.toml`.
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
