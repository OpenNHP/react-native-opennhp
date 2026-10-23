# Getting started

This walks through the first knock from a React Native app. Install and platform settings are in the [README](../README.md). iOS and Android project settings are in [platform setup](platform-setup.md).

## 1. Pick a working directory

```js
import { getDefaultWorkingDirectory } from "react-native-opennhp";

const workingDirectory = getDefaultWorkingDirectory();
```

On iOS this is the app Documents directory. On Android it is the app-private files directory. Both are writable without a storage permission. You can pass any other writable path to `initializeAgent` instead.

Create `etc` inside that directory before startup. The SDK creates `logs` itself.

## 2. Create an agent key

`generateKeys` does not require `initializeAgent`. It stores the private key in the iOS Keychain or in Android Keystore-wrapped storage and returns only the public key.

```js
import { Cipher, generateKeys } from "react-native-opennhp";

const keys = await generateKeys(Cipher.CURVE25519);
// keys.publicKey is base64. The private key stays on the device.
```

Use `Cipher.SM2` only when the nhp-server is configured for SM2. Curve25519 and SM2 keys are not interchangeable.

The sample `example/etc/config.toml` key is the public OpenNHP docker demo key. This module does not read that file. Generate a new key for any app you ship. If you already have a private key, `importAgentKey({ privateKey, cipher })` stores it once and returns `{ publicKey }`.

## 3. Start the agent and identify the user

```js
import { LogLevel, initializeAgent, setKnockUser } from "react-native-opennhp";

const ready = await initializeAgent(workingDirectory, LogLevel.INFO);
if (!ready) {
  throw new Error("Agent failed to start");
}

await setKnockUser({
  userId: "user-1",
  deviceId: "device-1",
  orgId: "example.org",
  userData: { role: "member" },
});
```

Startup takes about one second. `initializeAgent` returns `false` when no agent key is stored yet. It rejects when `etc/config.toml` still contains `PrivateKeyBase64`; delete that file. The reason for other startup failures is in `workingDirectory/logs`.

`userData` is sent with knock messages. Pass an object or a JSON string. Identity is not read from `config.toml`.

## 4. Register the server and knock

```js
import { addServer, knockResource } from "react-native-opennhp";

await addServer({
  pubkey: SERVER_PUBLIC_KEY,
  host: "nhp.example.com",
  port: 62206,
  expire: 0,
});

const ack = await knockResource("example", "demo", SERVER_PUBLIC_KEY);
```

`pubkey` is the nhp-server public key, base64, in the same cipher scheme as the agent. `host` is preferred. `ip` is used when `host` is empty. Port `0` selects `62206`. Expire `0` means the server key does not expire.

The third argument to `knockResource` is the cluster id. For a server added with `addServer`, that id is the server public key. `aspId` (`"example"`) and `resId` (`"demo"`) must match a resource the server is willing to open for this user.

A successful ack has `errCode` equal to the string `"0"`. `resHost` lists the hosts that were opened. `opnTime` is the open duration in seconds. `aspToken` and `redirectUrl` are present only when the server sends them.

## Register this device

Use this when the server must enroll the device key before it will accept knocks. Copy `server.toml` into `etc` first. An empty secure store makes `requestRegistrationOtp` generate a key and store it. A key already stored by `generateKeys` is the one that gets registered.

```js
import { requestRegistrationOtp, registerDevice } from "react-native-opennhp";

const pending = await requestRegistrationOtp({
  workingDirectory,
  email: "user@example.com",
  deviceId: "phone-1",
  aspId: "example",
  resId: "demo",
  cluster: "production",
});

const registered = await registerDevice({
  workingDirectory,
  email: "user@example.com",
  deviceId: "phone-1",
  aspId: "example",
  resId: "demo",
  cluster: "production",
  otp: "123456",
});
```

`pending.errCode` and `registered.errCode` are `"0"` on success. The private key stays in the secure store for the next launch. Field details are in [the API page](api.md).

## 5. Stop

```js
import { close } from "react-native-opennhp";

await close();
```

Call `close` when the user signs out or the app is finished with access. `close` stops the agent and leaves the stored key in place. Call `exitResource(aspId, resId, cluster)` first when you want the server to drop the opening before it expires on its own.

## Knock loop

If `etc/resource.toml` lists resources, `startKnockLoop()` knocks them in the background and refreshes them when that file changes. The return value is how many resources were queued, or `-1` when the agent has not been started. `stopKnockLoop()` stops that thread.

See [configuration](configuration.md) for the `resource.toml` shape.
