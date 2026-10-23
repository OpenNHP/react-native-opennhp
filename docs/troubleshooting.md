# Troubleshooting

Logs are files under `workingDirectory/logs`. `initializeAgent` only returns `true` or `false`, so the log file is the startup error.

## The JavaScript module throws "not linked"

The native app was not rebuilt after install, or iOS pods are stale.

```sh
cd ios && pod install
```

Then rebuild from Xcode or `npx react-native run-ios` / `run-android`. Expo Go cannot load the module. Use a development build.

## `initializeAgent` returns false

Check, in order:

1. `generateKeys`, `importAgentKey`, or `requestRegistrationOtp` has already stored an agent key. `getPublicKey()` returns an empty string when the secure store is empty.
2. `etc/config.toml` does not contain `PrivateKeyBase64`. That file makes the call reject with `E_OPENNHP` instead of returning `false`. Delete the file.
3. The directory is writable. `getDefaultWorkingDirectory()` is writable without extra permissions.

Then read the newest file in `workingDirectory/logs`.

## Knock returns a non-zero `errCode`

`errCode` is a string. Success is `"0"`. Read `errMsg` and the agent log.

Frequent causes:

- `initializeAgent` was not called, or it returned `false`.
- `cluster` does not match a `[[Servers]] Name`, and it is not the public key passed to `addServer`.
- `addServer` was missing `host` and `ip`, so it returned `false`.
- The server public key or cipher scheme does not match the server.
- UDP to that host and port is blocked. The mobile agent does not use the browser demo's HTTPS relay.
- On the Android emulator, the host machine is `10.0.2.2`. `127.0.0.1` is the emulator.
- On iOS, a server on the local network needs `NSLocalNetworkUsageDescription`.
- `example/etc` still points at docker addresses `177.7.0.9` and `177.7.0.14`.

## `startKnockLoop` returns `-1` or `0`

`-1` means the agent is not started. `0` means `etc/resource.toml` has no resources and `addResource` has not added any. The loop reloads `resource.toml` when the file changes.

## Startup is slow

`initializeAgent` waits about one second inside the OpenNHP SDK before it returns. That wait is part of agent startup.

## Build fails looking for `libnhpagent.so`

The app's ABI filter includes an architecture this package does not ship. Supported ABIs are `arm64-v8a`, `armeabi-v7a`, `x86`, and `x86_64`.

## iOS linker errors about Nhpagent

Run `pod install` again and confirm the app deployment target is 15.1 or newer. The framework is a static xcframework vendored by `react-native-opennhp.podspec`.
