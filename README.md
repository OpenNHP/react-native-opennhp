# react-native-opennhp

> [!WARNING]
> This repository is in active development and is not for production use. Active security concerns still need to be addressed.

React Native module for the [OpenNHP](https://github.com/OpenNHP/opennhp) client agent. It embeds the OpenNHP iOS and Android agent SDK so an app can knock on an nhp-server and open short-lived, zero-trust access to a protected resource.

The native libraries are already compiled. Install the package, add an agent config, and call the JavaScript API. You do not need Go, Xcode command-line builds, or the Android NDK unless you want to rebuild the SDK yourself.

| | |
| --- | --- |
| Platforms | iOS 15.1+ and Android (`minSdk` 24+, native libraries built for API 21) |
| ABIs | `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64` |
| OpenNHP pin | `main` commit [`9c4ff38`](https://github.com/OpenNHP/opennhp/commit/9c4ff38834964294835ddcdc6c97ae76095843d0) (2026-10-23) |
| License | Apache-2.0, including the bundled OpenNHP SDK |

Official OpenNHP agent SDK reference: [docs.opennhp.org/agent_sdk](https://docs.opennhp.org/agent_sdk/).

## Contents

- [Requirements](#requirements)
- [Install](#install)
- [Quick start](#quick-start)
- [Become a trusted device](#become-a-trusted-device)
- [Configuration](#configuration)
- [API](#api)
- [Which OpenNHP revision to ship](#which-opennhp-revision-to-ship)
- [Changelog](#changelog)
- [To do](#to-do)
- [More documentation](#more-documentation)

## Requirements

- React Native with autolinking (0.60 or newer), in a project you compile yourself. Expo Go cannot load this native module. Use a development build or `expo prebuild`.
- iOS 15.1 or newer, CocoaPods, and a rebuild after `pod install`.
- Android Gradle with Java 17. The library manifest adds `android.permission.INTERNET`.
- A reachable nhp-server. The mobile agent speaks UDP directly to the server. It does not use the public HTTPS relay that the browser demo uses.

## Install

From the app directory, install this package from a local checkout or from git, then install pods:

```sh
npm install /absolute/path/to/react-native-opennhp
cd ios && pod install
```

```sh
npm install github:YOUR_ORG/react-native-opennhp
cd ios && pod install
```

Rebuild the iOS and Android apps after installing. Autolinking registers the `OpenNhp` native module.

If the nhp-server is on the local network, add this to the iOS app `Info.plist`. iOS otherwise blocks that UDP traffic:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app contacts the local OpenNHP server.</string>
```

Android emulators reach a server on the host machine at `10.0.2.2`, not `127.0.0.1`.

## Quick start

The agent writes logs to `workingDirectory/logs/`. `getDefaultWorkingDirectory()` returns the iOS Documents directory or the Android app files directory. The private key never goes in a file or in JavaScript. `generateKeys` stores it in the iOS Keychain or in Android Keystore-wrapped storage, and returns only the public key.

`Cipher.CURVE25519` (`0`) is the default. Use `Cipher.SM2` (`1`) only when the nhp-server uses SM2. The key and the server must use the same scheme.

```js
import {
  Cipher,
  DEFAULT_SERVER_PORT,
  LogLevel,
  addServer,
  generateKeys,
  getDefaultWorkingDirectory,
  initializeAgent,
  knockResource,
  setKnockUser,
} from "react-native-opennhp";

const workingDirectory = getDefaultWorkingDirectory();
const keys = await generateKeys(Cipher.CURVE25519);
// Give keys.publicKey to the auth service. The private key stays on the device.

const ready = await initializeAgent(workingDirectory, LogLevel.INFO);
if (!ready) {
  throw new Error("OpenNHP failed to start. Read workingDirectory/logs.");
}

await setKnockUser({
  userId: "user-1",
  deviceId: "device-1",
  orgId: "example.org",
  userData: { role: "member" },
});

await addServer({
  pubkey: "<nhp-server public key>",
  host: "nhp.example.com",
  port: DEFAULT_SERVER_PORT,
  expire: 0,
});

const ack = await knockResource("example", "demo", "<nhp-server public key>");
if (ack.errCode !== "0") {
  throw new Error(ack.errMsg || "Knock failed");
}
```

`initializeAgent` takes about a second because the SDK waits during startup. `knockResource` waits for the server round trip. `ack.opnTime` is how many seconds the server opened access. `ack.resHost` maps resource host names to addresses.

When the server was added with `addServer`, pass that server's public key as the `cluster` argument. When the server comes from `server.toml`, pass the `[[Servers]] Name` instead.

## Become a trusted device

A knock is accepted only after the auth service knows this device's public key. There are two ways to get there.

### Add the public key by hand

`generateKeys` creates the key in the device secure store and returns `publicKey`. Give that public key to whoever administers the auth service. They add it as a trusted device for that user. No email step is involved. The app can knock once that key is recognized.

```js
import { Cipher, generateKeys } from "react-native-opennhp";

const keys = await generateKeys(Cipher.CURVE25519);
// Register keys.publicKey with the auth service by hand.
```

A key created outside the app can be installed once with `importAgentKey({ privateKey, cipher })`. That call stores the key and returns `publicKey`. It does not return the private key.

### Register with a one-time password

The app can enroll itself. `requestRegistrationOtp` asks the server to email a code, then `registerDevice` submits that code with the public key already in the secure store. The server needs SMTP for that mail.

Put `etc/server.toml` in the working directory first so the agent can find the nhp-server. On a server installed with the OpenNHP installer, a debug configuration also writes the one-time password to the server logs. Use that log line when mail is not being delivered.

The published OpenNHP iOS and Android SDKs do not export this flow. These two methods are provided by this module.

```js
import { requestRegistrationOtp, registerDevice } from "react-native-opennhp";

const pending = await requestRegistrationOtp({
  workingDirectory,
  email: "user@example.com",
  deviceId: "phone-1",
  orgId: "example.org",
  aspId: "example",
  resId: "demo",
  cluster: "production",
});
if (pending.errCode !== "0") {
  throw new Error(pending.errMsg || "OTP request failed");
}

const registered = await registerDevice({
  workingDirectory,
  email: "user@example.com",
  deviceId: "phone-1",
  orgId: "example.org",
  aspId: "example",
  resId: "demo",
  cluster: "production",
  otp: codeFromEmail,
});
```

`registered.errCode === "0"` means the server accepted the public key. The private key is already in the secure store, so the next launch only needs `initializeAgent`. `expiresAt` is a Unix timestamp when the server set a key lifetime. `close()` does not delete the stored key.

## Configuration

Layout the SDK expects:

```text
<workingDirectory>/
  etc/
    server.toml      optional if you call addServer
    resource.toml    optional; startKnockLoop knocks these resources
    dhp.toml         optional
  logs/              created by the SDK
```

Do not write `etc/config.toml`. The agent private key lives in the iOS Keychain, or in ciphertext wrapped by an Android Keystore AES key. The account name is `org.opennhp.agent` / `agent-private-key`. If an older `config.toml` still contains `PrivateKeyBase64`, `initializeAgent` rejects it until that file is deleted.

`example/etc` contains the OpenNHP docker demo files, including a sample `config.toml` this module does not read. Those files use a published demo key and the docker addresses `177.7.0.9` and `177.7.0.14`. Replace the server addresses before pointing an app at a real server.

Full field reference and the knock loop: [docs/configuration.md](docs/configuration.md).

## API

Every method except `getDefaultWorkingDirectory()` returns a promise. Native calls run one at a time.

| Method | What it does |
| --- | --- |
| `getDefaultWorkingDirectory()` | App directory to use as `workingDirectory`. |
| `generateKeys(cipher)` | Create a key in the secure store. Resolves `{ publicKey }`. `Cipher.CURVE25519` (`0`) or `Cipher.SM2` (`1`). |
| `getPublicKey()` | Public key of the stored agent key, or an empty string when none is stored. |
| `importAgentKey({ privateKey, cipher })` | Store a key created outside the app. Resolves `{ publicKey }`. |
| `requestRegistrationOtp(options)` | Email a one-time password for the stored key, or generate and store one. |
| `registerDevice(options)` | Register the stored public key with the one-time password. |
| `initializeAgent(dir, logLevel)` | Start the agent from the stored key. Returns `false` when no key is stored or startup fails. |
| `close()` | Stop the agent and release it. |
| `setKnockUser({ userId, deviceId, orgId, userData })` | Identity sent with each knock. |
| `addServer({ pubkey, ip, host, port, expire })` | Register one nhp-server. Port `0` uses `62206`. Expire `0` does not expire. |
| `removeServer(pubkey)` | Drop a server registered with `addServer`. |
| `addResource(aspId, resId, cluster)` | Add a resource to the knock loop. |
| `removeResource(aspId, resId)` | Remove a resource from the knock loop. |
| `knockResource(aspId, resId, cluster)` | One knock. Resolves to the server JSON. |
| `exitResource(aspId, resId, cluster)` | Ask the server to drop access early. |
| `startKnockLoop()` | Knock every resource in `resource.toml`. Returns the resource count, or `-1` when the agent is not started. |
| `stopKnockLoop()` | Stop the background knock loop. |

`LogLevel` for `initializeAgent` is `0` silent, `1` error, `2` info, `3` debug, `4` verbose. That argument is the log level when `config.toml` is absent.

Argument and response details: [docs/api.md](docs/api.md).

## Which OpenNHP revision to ship

This module normally tracks the latest OpenNHP release tag. A release tag is a numbered contract with release notes; `main` moves without one. The binaries are currently an exception: they are built from `main` because the agent-init fix this module needs ([OpenNHP PR #1806](https://github.com/OpenNHP/opennhp/pull/1806)) is merged on `main` but is not yet in a tagged release. Building from `main` lets the module drop the local copy of that fix instead of carrying a patch that now duplicates upstream.

The binaries in this repository are built from `main` commit [`9c4ff38`](https://github.com/OpenNHP/opennhp/commit/9c4ff38834964294835ddcdc6c97ae76095843d0) (2026-10-23), recorded in `OPENNHP_REVISION`. The build also applies one local patch, `scripts/opennhp-agent-sdk.patch`, which adds the device-registration flow that the upstream mobile SDKs do not export (closed PRs [#1807](https://github.com/OpenNHP/opennhp/pull/1807) / [#1808](https://github.com/OpenNHP/opennhp/pull/1808), pending rework).

`scripts/build-sdks.sh` fetches `main` by default. To reproduce a specific build or move to a future release, pass a ref: `OPENNHP_REF=v1.0.3 ./scripts/build-sdks.sh`, then update `OPENNHP_REVISION`. Return to tracking release tags once a release carries PR #1806 and the registration flow lands upstream.

## Changelog

`package.json` is still `0.1.0`. Work after that release is listed under Unreleased until the next publish. The 0.1.0 binaries were built from OpenNHP `main` commit `3c78548`. Unreleased moves the pin to `main` commit `9c4ff38`.

### Unreleased

- Add `requestRegistrationOtp` and `registerDevice`. The upstream iOS and Android SDKs do not export device registration, so this module adds that flow.
- Store the agent private key in the iOS Keychain, and on Android encrypt it with an Android Keystore AES key. JavaScript receives the public key only.
- Start the agent from that stored key. `config.toml` is no longer where the private key lives. A leftover `PrivateKeyBase64` in that file makes startup fail until the file is deleted.
- Add `getPublicKey` and `importAgentKey`. `importAgentKey` is the one call that accepts a private key, and it does not return it.
- Keep the registration implementation in one OpenNHP agent file, `sdk_register.go`. The iOS and Android exports are wrappers around it.
- Build the native libraries from OpenNHP `main` commit `9c4ff38`. The agent-init fix (PR #1806) is now merged upstream, so the build drops the local `opennhp-agent-init-fix.patch` and applies only the registration patch.

### 0.1.0 — 2026-10-22

- First release of the React Native module for the OpenNHP client agent.
- Ship prebuilt libraries for iOS 15.1+ and Android ABIs `arm64-v8a`, `armeabi-v7a`, `x86`, and `x86_64`.
- Knock, run the knock loop, add and remove servers and resources, and generate keys from JavaScript.

## To do

- [ ] Return to building from a tagged OpenNHP release once a release includes the agent-init fix (PR #1806) and the registration flow is upstreamed. The build currently tracks `main` for those changes.
- [ ] Move the iOS and Android SDKs into their own repository and include that repository here, so SDK releases and this React Native module can be updated separately.
- [x] Store the agent private key in the iOS Keychain, and on Android encrypt it with an Android Keystore AES key. A raw Curve25519 or SM2 key cannot live in the Android Keystore itself.
- [x] Keep the private key out of JavaScript. `generateKeys`, registration, and startup return or use only the public key.
- [x] Persist one agent key at `org.opennhp.agent` / `agent-private-key`. `deviceId` stays the knock identity, so the store name does not reuse it.
- [x] Document secure storage and stop telling apps to write the private key into `config.toml`. 

## More documentation

- [Getting started](docs/getting-started.md)
- [Configuration](docs/configuration.md)
- [JavaScript API](docs/api.md)
- [iOS and Android setup](docs/platform-setup.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Rebuild the native SDK](docs/building.md)

Upstream agent SDK: [docs.opennhp.org/agent_sdk](https://docs.opennhp.org/agent_sdk/). The bundled OpenNHP license is [licenses/OpenNHP-Apache-2.0.txt](licenses/OpenNHP-Apache-2.0.txt).
