# react-native-opennhp

An [OpenNHP](https://github.com/OpenNHP/opennhp) client agent for React Native. Knock on an OpenNHP server from iOS and Android to open short-lived access to a protected resource.

> [!WARNING]
> **Not production-ready.** This module is under active development and has open security concerns. Its native libraries are built from OpenNHP `main` plus a local patch (`scripts/opennhp-agent-sdk.patch`) that adds device registration, a change not yet merged upstream. Review that patch and pin a known commit before shipping.

The module bundles the OpenNHP iOS and Android agent SDK and exposes it to JavaScript. The native libraries are prebuilt, so you don't need Go, the Android NDK, or a manual Xcode build, unless you want to [rebuild them yourself](docs/building.md).

New to OpenNHP? Read the [OpenNHP documentation](https://docs.opennhp.org) first. This README covers the React Native binding only and assumes you already know what a knock is and have a reachable nhp-server.

## Features

- Generates and stores the agent key in the iOS Keychain / Android Keystore. The private key never reaches JavaScript or touches disk.
- Knock a resource on demand, or run a background knock loop over `resource.toml`.
- Register servers and resources from JavaScript. No TOML required.
- Enroll a device with a one-time password (`requestRegistrationOtp` / `registerDevice`), a flow the stock OpenNHP mobile SDKs don't expose.

## Requirements

- React Native 0.60+ with autolinking, in an app you build yourself. Expo Go can't load native modules, so use a development build or `expo prebuild`.
- iOS 15.1+ with CocoaPods.
- Android with Java 17 (`minSdk` 24; libraries built for API 21, ABIs `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`).
- A reachable nhp-server. The agent speaks UDP directly to it.

## Installation

```sh
npm install react-native-opennhp
cd ios && pod install
```

Rebuild the app afterward; autolinking registers the `OpenNhp` native module. While this package is unpublished you can install it from a local path or a git URL instead of npm.

Two platform notes:

- **iOS, server on the local network.** Add this to the app's `Info.plist`, or iOS blocks the UDP traffic:

  ```xml
  <key>NSLocalNetworkUsageDescription</key>
  <string>This app contacts the local OpenNHP server.</string>
  ```

- **Android emulator.** Reach a server running on your machine at `10.0.2.2`, not `127.0.0.1`.

## Usage

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

// Create the agent key once. Only the public key comes back; the private key
// stays in the device's secure store. Hand publicKey to your auth service.
const { publicKey } = await generateKeys(Cipher.CURVE25519);

const ready = await initializeAgent(workingDirectory, LogLevel.INFO);
if (!ready) {
  throw new Error("OpenNHP failed to start. Check workingDirectory/logs.");
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

Notes:

- `initializeAgent` and `knockResource` each take about a second (SDK startup, then the server round trip).
- For the `cluster` argument, pass the server's public key when you added it with `addServer`, or the `[[Servers]] Name` when it comes from `server.toml`.
- Use `Cipher.SM2` (`1`) only when the server uses SM2. The key and the server must use the same scheme.

See [docs/getting-started.md](docs/getting-started.md) for a fuller walkthrough.

## Device registration

A knock is accepted only once the auth service trusts the device's public key. You can do this two ways:

- **Out of band.** Call `generateKeys`, then give `publicKey` to whoever administers the auth service to add as a trusted device.
- **One-time password.** The app enrolls itself: `requestRegistrationOtp` asks the server to email a code, and `registerDevice` submits that code with the stored public key. The server needs SMTP configured.

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
if (pending.errCode !== "0") throw new Error(pending.errMsg || "OTP request failed");

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

`registered.errCode === "0"` means the server accepted the key. It's already in the secure store, so later launches only need `initializeAgent`. The registration methods are added by this module; the upstream OpenNHP mobile SDKs don't export them.

## API

Every method except `getDefaultWorkingDirectory()` returns a promise, and native calls run one at a time.

| Method | Description |
| --- | --- |
| `getDefaultWorkingDirectory()` | App directory to use as `workingDirectory`. |
| `generateKeys(cipher)` | Create a key in the secure store. Resolves `{ publicKey }`. |
| `getPublicKey()` | Public key of the stored key, or `""` when none is stored. |
| `importAgentKey({ privateKey, cipher })` | Store a key created elsewhere. Resolves `{ publicKey }`; never returns the private key. |
| `requestRegistrationOtp(options)` | Ask the server to email a one-time password for the device. |
| `registerDevice(options)` | Register the stored public key with that one-time password. |
| `initializeAgent(dir, logLevel)` | Start the agent from the stored key. Resolves `false` if no key is stored or startup fails. |
| `close()` | Stop the agent. Does not delete the stored key. |
| `setKnockUser({ userId, deviceId, orgId, userData })` | Identity sent with each knock. |
| `addServer({ pubkey, ip, host, port, expire })` | Register a server. Port `0` means `62206`; expire `0` never expires. |
| `removeServer(pubkey)` | Drop a server added with `addServer`. |
| `addResource(aspId, resId, cluster)` | Add a resource to the knock loop. |
| `removeResource(aspId, resId)` | Remove a resource from the knock loop. |
| `knockResource(aspId, resId, cluster)` | One knock; resolves to the server's JSON ack. |
| `exitResource(aspId, resId, cluster)` | Ask the server to drop access early. |
| `startKnockLoop()` | Knock every resource in `resource.toml`; resolves the resource count, or `-1` if not started. |
| `stopKnockLoop()` | Stop the background knock loop. |

`LogLevel` runs `0` silent, `1` error, `2` info, `3` debug, `4` verbose. Full argument and response shapes are in [docs/api.md](docs/api.md).

## Configuration

The SDK reads TOML from a working directory:

```text
<workingDirectory>/
  etc/
    server.toml      optional, or call addServer
    resource.toml    optional; startKnockLoop knocks these
    dhp.toml         optional
  logs/              created by the SDK
```

Do **not** create `etc/config.toml`. The private key lives in the iOS Keychain or in Android Keystore-wrapped storage, not in a file, and `initializeAgent` refuses to start if `config.toml` still contains a `PrivateKeyBase64`. Field reference and the knock loop: [docs/configuration.md](docs/configuration.md).

## Building from source

The prebuilt binaries are built from OpenNHP `main` commit [`9c4ff38`](https://github.com/OpenNHP/opennhp/commit/9c4ff38834964294835ddcdc6c97ae76095843d0) (recorded in `OPENNHP_REVISION`) plus the local registration patch. `scripts/build-sdks.sh` fetches `main` by default; pass `OPENNHP_REF=<tag|commit>` to pin a different revision. See [docs/building.md](docs/building.md).

## Learn more about OpenNHP

This module is just the React Native binding. For the protocol, server setup, and agent concepts, go to the source:

- Project: [github.com/OpenNHP/opennhp](https://github.com/OpenNHP/opennhp)
- Documentation: [docs.opennhp.org](https://docs.opennhp.org)
- Agent SDK reference: [docs.opennhp.org/agent_sdk](https://docs.opennhp.org/agent_sdk/)

## Documentation

- [Getting started](docs/getting-started.md)
- [Configuration](docs/configuration.md)
- [JavaScript API](docs/api.md)
- [iOS and Android setup](docs/platform-setup.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Rebuild the native SDK](docs/building.md)

## Changelog

### 0.2.0

- Add device registration: `requestRegistrationOtp` and `registerDevice`, plus `getPublicKey` and `importAgentKey`.
- Keep the agent private key in the iOS Keychain / Android Keystore. It is never returned to JavaScript. A generated key is handed to native secure storage through a dedicated channel, never in a response body.
- Build the native libraries from OpenNHP `main`, since the agent-init fix this module needs ([PR #1806](https://github.com/OpenNHP/opennhp/pull/1806)) is merged there but not yet in a release.

### 0.1.0

- First release: knock, the knock loop, server/resource management, and key generation from JavaScript. Prebuilt for iOS 15.1+ and Android `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`.

## License

Apache-2.0, including the bundled OpenNHP SDK. See [licenses/OpenNHP-Apache-2.0.txt](licenses/OpenNHP-Apache-2.0.txt).
