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
  initializeAgent,
  knockResource,
  privateKeyToPublicKey,
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

Returns `{ privateKey, publicKey }`, both base64. Does not require `initializeAgent`.

`cipher` is `Cipher.CURVE25519` or `Cipher.SM2`. Any other value follows the SDK default, which is Curve25519.

### `privateKeyToPublicKey(privateKey, cipher = Cipher.CURVE25519)`

Returns the base64 public key. Returns an empty string when the private key is not valid for that cipher.

## Lifecycle

### `getDefaultWorkingDirectory()`

iOS Documents directory, or the Android `files` directory.

### `initializeAgent(workingDirectory, logLevel = LogLevel.INFO)`

Starts the agent process inside the app. Returns `true` when the agent is running. Returns `true` immediately when it is already running. Returns `false` when `etc/config.toml` is missing, the private key is missing or invalid, or startup fails. Read `workingDirectory/logs` for the SDK error.

Rejects when `workingDirectory` is empty.

The `logLevel` argument uses `LogLevel` (`0` through `4`). `config.toml` `LogLevel` (`0` through `5`) replaces it after the file loads.

### `close()`

Stops the agent and releases it. The next `initializeAgent` starts a new session and reads config again.

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

## Errors from the native bridge

A native crash or a linkage failure rejects the promise with code `E_OPENNHP` on Android. iOS rejects through the React Native bridge. If `NativeModules.OpenNhp` is missing, the JavaScript call throws `react-native-opennhp is not linked` before any native work. Rebuild after install, and run `pod install` on iOS.
