# Configuration

The agent reads TOML from `workingDirectory/etc` and writes logs to `workingDirectory/logs`. Paths are the same on iOS and Android.

```text
<workingDirectory>/
  etc/
    config.toml
    server.toml
    resource.toml
    dhp.toml
  logs/
```

`config.toml` is required. The other files are optional when you register servers and resources from JavaScript. `example/etc` is a copy of the OpenNHP docker demo. Treat it as a schema sample. Its addresses are docker bridge addresses, and its private key is a published demo key.

Upstream field reference: [OpenNHP agent SDK](https://docs.opennhp.org/agent_sdk/).

## config.toml

```toml
PrivateKeyBase64 = "<base64 private key>"
DefaultCipherScheme = 0
UserId = "user-1"
OrganizationId = "example.org"
LogLevel = 2

[UserData]
role = "member"
```

| Field | Required | Meaning |
| --- | --- | --- |
| `PrivateKeyBase64` | Yes | Agent private key. A plain base64 key, or a sealed blob that starts with `v1$`. |
| `DefaultCipherScheme` | Yes | `0` Curve25519, `1` SM2. Must match the key and the nhp-server. |
| `UserId` | Recommended | User this agent represents. |
| `OrganizationId` | Optional | Organization id sent with knocks. |
| `LogLevel` | Optional | File log level. `0` silent, `1` error, `2` info, `3` audit, `4` debug, `5` trace. |
| `UserData` | Optional | Extra JSON-like fields sent with each knock. |

`initializeAgent(dir, logLevel)` sets the logger first. After `config.toml` loads, the file's `LogLevel` replaces that argument.

A sealed private key (`v1$...`) is decrypted with the `NHP_KEY_PASSPHRASE` or `NHP_KEY_PASSPHRASE_FILE` environment variable. This module does not set those variables. Mobile apps should store the plain base64 key produced by `generateKeys` in app-private storage.

Empty `PrivateKeyBase64` makes `initializeAgent` return `false`.

## server.toml

Use this file when the server list should live on disk. `addServer` is the equivalent at runtime.

Each `[[Servers]]` block is one nhp-server identity (one public key) and one or more network instances.

```toml
[[Servers]]
Name = "production"
PubKeyBase64 = "<server public key>"
ExpireTime = 1924991999
LoadBalance = "weighted-random"
StickyInstance = true

  [[Servers.Instances]]
  Host = "nhp.example.com"
  Port = 62206
  Weight = 1
```

| Field | Meaning |
| --- | --- |
| `Name` | Cluster id used as the `cluster` argument to `knockResource`, `addResource`, and `exitResource`. Letters, numbers, `.`, `_`, and `-`, up to 64 characters. |
| `PubKeyBase64` | Server public key. Curve25519 when `DefaultCipherScheme` is `0`, SM2 when it is `1`. |
| `ExpireTime` | Unix seconds. The agent rejects the peer after this time. |
| `LoadBalance` | `weighted-random` (default), `random`, or `round-robin`. |
| `StickyInstance` | When `true` (default), the knock and its follow-up stay on the same instance. Set `false` only when every instance shares a stateless cookie key. |
| `Host` | DNS name. Resolved when a packet is sent. Preferred over `Ip`. |
| `Ip` | Static address, used when `Host` is empty. |
| `Port` | UDP port. Required and greater than 0 in this file. |
| `Weight` | Relative weight for `weighted-random`. Default `1`. |

Calling `addServer` builds a one-instance cluster whose name is the server public key. Pass that public key as `cluster` in later calls. Calling `addServer` again with the same public key replaces the previous address. Multi-instance clusters belong in `server.toml`.

A legacy flat `[[Servers]]` block with `Ip` and `Port` on the server itself still loads. New files should use `[[Servers.Instances]]`.

## resource.toml

`startKnockLoop()` knocks every resource in this file and reloads the file when it changes.

```toml
[[Resources]]
AuthServiceId = "example"
ResourceId = "demo"
Cluster = "production"
```

`Cluster` is a `[[Servers]] Name` from `server.toml`. It is the server public key when that server was created with `addServer`.

`addResource(aspId, resId, cluster)` adds the same kind of entry in memory for the running loop.

## dhp.toml

Optional data-hiding configuration. Startup continues when this file is missing or invalid.

```toml
TEEPrivateKeyBase64 = "<base64 TEE private key>"
```

Leave the file out until you use that protocol. The docker sample value is a published demo key.

## What the app has to match

- Agent cipher scheme, agent key, and server public key are the same algorithm.
- `cluster` names a server the agent already loaded from `server.toml` or `addServer`.
- `AuthServiceId` and `ResourceId` name a resource that server will open for this user.
- The phone can send UDP to `Host` or `Ip` on `Port`. The mobile SDK does not send knocks through the HTTPS relay used by the browser demo.
