# JavaScript API

Import from `react-native-opennhp`. TypeScript types ship in `src/index.d.ts`.

```js
import {
  Cipher,
  DEFAULT_SERVER_PORT,
  LogLevel,
  addResource,
  addServer,
  close,
  exitResource,
  generateKeys,
  getDefaultWorkingDirectory,
  getPublicKey,
  importAgentKey,
  initializeAgent,
  knockResource,
  removeResource,
  removeServer,
  setKnockUser,
  startKnockLoop,
  stopKnockLoop,
} from "react-native-opennhp";
```

Native methods run one at a time on a background queue. Overlapping JavaScript calls wait. A knock blocks that queue until the server responds or the SDK gives up.

`getDefaultWorkingDirectory()` is synchronous and throws when the native module is not linked.

## Constants

| Export | Value |
| --- | --- |
| `LogLevel.SILENT` | `0` |
| `LogLevel.ERROR` | `1` |
| `LogLevel.INFO` | `2` |
| `LogLevel.DEBUG` | `3` |
| `LogLevel.VERBOSE` | `4` |
| `Cipher.CURVE25519` | `0` |
| `Cipher.SM2` | `1` |
| `DEFAULT_SERVER_PORT` | `62206` |

## Keys

### `generateKeys(cipher = Cipher.CURVE25519)`

Creates a key pair, stores the private key in the device secure store, and returns `{ publicKey }`. Does not require `initializeAgent`. Replaces any key already in the store.

`cipher` is `Cipher.CURVE25519` or `Cipher.SM2`. Any other value follows the SDK default, which is Curve25519.

### `getPublicKey()`

Returns the base64 public key of the stored agent key. Returns an empty string when no key is stored.

### `importAgentKey({ privateKey, cipher = Cipher.CURVE25519 })`

Stores a private key that was created outside the app and returns `{ publicKey }`. This is the only JavaScript call that accepts a private key, and it does not return that key. Rejects when the key is not valid for `cipher`. Replaces any key already in the store.

## Lifecycle

### `getDefaultWorkingDirectory()`

iOS Documents directory, or the Android `files` directory.

### `initializeAgent(workingDirectory, logLevel = LogLevel.INFO)`

Starts the agent process inside the app from the key in the secure store. Returns `true` when the agent is running. Returns `true` immediately when it is already running. Returns `false` when no key is stored, the stored key is invalid, or startup fails. Read `workingDirectory/logs` for the SDK error.

Rejects when `workingDirectory` is empty. Rejects with `E_OPENNHP` when `etc/config.toml` contains `PrivateKeyBase64`.

The `logLevel` argument uses `LogLevel` (`0` through `4`). With no `config.toml`, that argument stays in effect.

### `close()`

Stops the agent and releases it. The stored key remains. The next `initializeAgent` starts a new session from that key.

## Identity

### `setKnockUser(user)`

```ts
type KnockUser = {
  userId?: string;
  deviceId?: string;
  orgId?: string;
  userData?: Record<string, unknown> | string;
};
```

Returns `false` when the agent is not started or `userData` is a string that is not JSON. Objects are serialized. Omitted fields are sent as empty.

## Servers and resources

### `addServer(server)`

```ts
type ServerPeer = {
  pubkey: string;
  ip?: string;
  host?: string;
  port?: number;
  expire?: number;
};
```

Returns `false` when the agent is not started, `pubkey` is empty, or both `ip` and `host` are empty.

`port` omitted or `0` uses `62206`. `expire` omitted or `0` means the public key does not expire. `expire` is Unix time in seconds.

The cluster name for this server is `pubkey`. Pass that string as `cluster` to `knockResource`, `addResource`, and `exitResource`.

### `removeServer(pubkey)`

Removes a server registered with `addServer`.

### `addResource(aspId, resId, cluster)`

Adds a resource to the in-memory knock set. Returns `false` when the agent is not started or `cluster` does not match a loaded server.

### `removeResource(aspId, resId)`

Removes that resource from the in-memory knock set.

### `startKnockLoop()`

Starts the background knocker. It reads `etc/resource.toml` and follows later edits to that file. Returns the number of resources queued, or `-1` when the agent is not started.

### `stopKnockLoop()`

Stops the background knocker.

## Knock and exit

### `knockResource(aspId, resId, cluster)`

Sends one knock. Resolves to the server acknowledgement:

```ts
type KnockAck = {
  errCode?: string;
  errMsg?: string;
  resHost?: Record<string, string>;
  opnTime?: number;
  aspToken?: string;
  agentAddr?: string;
  acTokens?: Record<string, string>;
  preActions?: unknown;
  redirectUrl?: string;
  raw?: string;
};
```

`errCode` is the string `"0"` on success. On failure, branch on `errCode` and show `errMsg`. Common failures:

| Situation | What you see |
| --- | --- |
| Agent not started | Error code for no agent instance |
| Empty `aspId`, `resId`, or `cluster` | Invalid input |
| `cluster` is not a known name or public key | Unknown cluster |

When the response is not JSON, the promise still resolves, with `errCode` set to `-1`, `errMsg` set to a parse error, and the original text in `raw`.

`resHost` maps a resource host name to the address the server opened. `opnTime` is how long that opening lasts, in seconds. `agentAddr` is this device's address as the nhp-server sees it. `aspToken`, `acTokens`, `preActions`, and `redirectUrl` are included only when the server sends them.

### `exitResource(aspId, resId, cluster)`

Tells the server to drop this resource's opening. Returns `true` when the SDK reports success.

## Device registration

`requestRegistrationOtp` and `registerDevice` follow the `nhp-agentd register` flow: ask the server to email a one-time password, then submit that code with this device's public key.

`etc/server.toml` must already name the cluster. Registration does not replace the key of an agent that is already running. When that agent holds the same key and cipher scheme, the OTP and register calls use it, including any server added with `addServer`. Otherwise close the agent first. A new key is generated only when no agent is running, and that call reads `server.toml` from the working directory. When the secure store is empty, the OTP request generates a key and stores it. When a key is already stored, that key is the one registered.

```ts
type RegistrationOptions = {
  workingDirectory: string;
  logLevel?: LogLevelValue;
  cipher?: CipherValue;
  email: string;
  deviceId?: string;
  orgId?: string;
  userData?: Record<string, unknown> | string;
  aspId: string;
  resId: string;
  cluster: string;
};
```

### `requestRegistrationOtp(options)`

Sends `NHP-OTP`. `email` is the user id and `UserData.email`, which is where the server sends the code. `cipher` selects the scheme only when the secure store is empty. An existing stored key keeps its own cipher.

Resolves to:

```ts
type RegistrationResult = {
  errCode?: string;
  errMsg?: string;
  publicKey?: string;
  raw?: string;
};
```

`errCode` `"0"` means the OTP request was sent. The private key is stored on the device and is not part of this result. The call does not wait for the email itself.

### `registerDevice({ ...options, otp })`

Sends `NHP-REG` with the stored agent key. Rejects when the secure store is empty. A relaunch between the OTP request and this call still uses the same key.

On success, `errCode` is `"0"`. `expiresAt` is Unix seconds when the server limited the key lifetime, and it is omitted when the key does not expire. `aspId` echoes the auth service when the server sends it. The next `initializeAgent` loads the stored key. No `config.toml` write is required.

## Errors from the native bridge

A rejected call uses the code `E_OPENNHP`. That includes a missing secure-store key on `registerDevice`, a private key left in `etc/config.toml`, and a key the secure store could not save. If `NativeModules.OpenNhp` is missing, the JavaScript call throws `react-native-opennhp is not linked` before any native work. Rebuild after install, and run `pod install` on iOS.
