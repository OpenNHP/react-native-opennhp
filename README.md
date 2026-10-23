# react-native-opennhp

React Native module for the [OpenNHP](https://github.com/OpenNHP/opennhp) client agent. It embeds the OpenNHP iOS and Android agent SDK so an app can knock on an nhp-server and open short-lived, zero-trust access to a protected resource.

The native libraries are already compiled. Install the package, add an agent config, and call the JavaScript API. You do not need Go, Xcode command-line builds, or the Android NDK unless you want to rebuild the SDK yourself.

| | |
| --- | --- |
| Platforms | iOS 15.1+ and Android (`minSdk` 24+, native libraries built for API 21) |
| ABIs | `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64` |
| OpenNHP pin | [`3c78548`](https://github.com/OpenNHP/opennhp/commit/3c78548d30eead779cb17dd9c37072d9e2e6be5d) on `main` (2026-10-21) |
| Latest OpenNHP release at build time | [v1.0.2](https://github.com/OpenNHP/opennhp/releases/tag/v1.0.2) (2026-09-11) |
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

The agent reads `workingDirectory/etc/config.toml` and writes logs to `workingDirectory/logs/`. `getDefaultWorkingDirectory()` returns the iOS Documents directory or the Android app files directory.

Create the config before calling `initializeAgent`. This module does not write files for you. `react-native-fs` and `expo-file-system` both work. A minimal file looks like this:

```toml
PrivateKeyBase64 = "<base64 private key>"
DefaultCipherScheme = 0
UserId = "user-1"
OrganizationId = "example.org"
LogLevel = 2
```

`DefaultCipherScheme = 0` is Curve25519. Use `1` for SM2. The key, this setting, and the nhp-server must all use the same scheme.

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
// Write keys.privateKey into etc/config.toml, then:

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

Generate a key pair, store the private key in `etc/config.toml`, and give the public key to whoever administers the auth service. They add it as a trusted device for that user. No email step is involved. The app can knock once that key is recognized.

```js
import { Cipher, generateKeys } from "react-native-opennhp";

const keys = await generateKeys(Cipher.CURVE25519);
// Save keys.privateKey in etc/config.toml.
// Register keys.publicKey with the auth service by hand.
```

### Register with a one-time password

The app can enroll itself. `requestRegistrationOtp` asks the server to email a code, then `registerDevice` submits that code with this device's public key. The server needs SMTP for that mail.

Put `etc/server.toml` in the working directory first so the agent can find the nhp-server. `config.toml` can be absent for these two calls. On a server installed with the OpenNHP installer, a debug configuration also writes the one-time password to the server logs. Use that log line when mail is not being delivered.

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
  privateKey: pending.privateKey,
  otp: codeFromEmail,
});
```

Save `registered.privateKey` into `etc/config.toml` before the next cold start. These calls do not write that file. `registered.errCode === "0"` means the server accepted the public key. `expiresAt` is a Unix timestamp when the server set a key lifetime.

## Configuration

Layout the SDK expects:

```text
<workingDirectory>/
  etc/
    config.toml      required
    server.toml      optional if you call addServer
    resource.toml    optional; startKnockLoop knocks these resources
    dhp.toml         optional
  logs/              created by the SDK
```

`example/etc` contains the OpenNHP docker demo files. Those files use a published demo key and the docker addresses `177.7.0.9` and `177.7.0.14`. Replace them before pointing an app at a real server.

Full field reference, cipher schemes, sealed keys, and the knock loop: [docs/configuration.md](docs/configuration.md).

## API

Every method except `getDefaultWorkingDirectory()` returns a promise. Native calls run one at a time.

| Method | What it does |
| --- | --- |
| `getDefaultWorkingDirectory()` | App directory to use as `workingDirectory`. |
| `generateKeys(cipher)` | New key pair. `Cipher.CURVE25519` (`0`) or `Cipher.SM2` (`1`). |
| `privateKeyToPublicKey(privateKey, cipher)` | Public key for an existing private key. |
| `requestRegistrationOtp(options)` | Email a one-time password and return the device key pair. |
| `registerDevice(options)` | Register that public key with the one-time password. |
| `initializeAgent(dir, logLevel)` | Start the agent. Returns `false` when startup fails. |
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

`LogLevel` for `initializeAgent` is `0` silent, `1` error, `2` info, `3` debug, `4` verbose. After startup, `LogLevel` inside `config.toml` replaces it. That file uses a wider scale: `0` silent through `5` trace.

Argument and response details: [docs/api.md](docs/api.md).

## Which OpenNHP revision to ship

Keep this module pinned to one OpenNHP commit. A floating "latest" build would change knock behavior between publishes with no release note.

The binaries in this repository are pinned to main commit `3c78548` (2026-10-21), recorded in `OPENNHP_REVISION`. That commit is newer than the latest GitHub release, [v1.0.2](https://github.com/OpenNHP/opennhp/releases/tag/v1.0.2) (2026-09-11). Main includes later agent work, including sealed private keys and agent DNS error reporting.

Use a release tag as the pin when you want a numbered OpenNHP contract and release notes. Keep this main snapshot when you want those later agent fixes. Rebuilding onto v1.0.2, or onto a future tag, is a deliberate SDK upgrade: change `COMMIT` in `scripts/build-sdks.sh`, run the script, and update `OPENNHP_REVISION`.

## To do

- [ ] Build from the latest OpenNHP release instead of the pinned commit `3c78548`.
- [ ] Move the iOS and Android SDKs into their own repository and include that repository here, so SDK releases and this React Native module can be updated separately.

## More documentation

- [Getting started](docs/getting-started.md)
- [Configuration](docs/configuration.md)
- [JavaScript API](docs/api.md)
- [iOS and Android setup](docs/platform-setup.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Rebuild the native SDK](docs/building.md)

Upstream agent SDK: [docs.opennhp.org/agent_sdk](https://docs.opennhp.org/agent_sdk/). The bundled OpenNHP license is [licenses/OpenNHP-Apache-2.0.txt](licenses/OpenNHP-Apache-2.0.txt).
