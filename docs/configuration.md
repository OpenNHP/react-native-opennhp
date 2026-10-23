# Configuration

The agent reads TOML from `workingDirectory/etc` and writes logs to `workingDirectory/logs`. Paths are the same on iOS and Android.

```text
<workingDirectory>/
  etc/
    server.toml
    resource.toml
    dhp.toml
  logs/
```

`server.toml`, `resource.toml`, and `dhp.toml` are optional when you register servers and resources from JavaScript. `example/etc` is a copy of the OpenNHP docker demo, including a `config.toml` this module does not read. Treat it as a schema sample. Its addresses are docker bridge addresses, and its private key is a published demo key.

Upstream field reference: [OpenNHP agent SDK](https://docs.opennhp.org/agent_sdk/).

## Agent key

The module does not use `etc/config.toml`. `generateKeys` and `requestRegistrationOtp` store the agent private key in the iOS Keychain, or encrypt it with an AES key that lives in the Android Keystore. JavaScript receives the public key only.

The store account is `org.opennhp.agent` / `agent-private-key`. There is one key per app. The cipher scheme is stored beside it: `0` Curve25519, `1` SM2. It must match the nhp-server.

`setKnockUser` supplies the user id, organization, device id, and extra user data that a desktop `config.toml` would have held. `initializeAgent(dir, logLevel)` supplies the log level when no `config.toml` is present.

If `etc/config.toml` contains a non-empty `PrivateKeyBase64`, `initializeAgent`, `requestRegistrationOtp`, and `registerDevice` reject the call. Delete that file. The module will not copy the plaintext key into the secure store for you. Use `importAgentKey` when the key was issued outside the app.

`close()` does not remove the stored key. The next `initializeAgent` loads it.

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
| `PubKeyBase64` | Server public key. Curve25519 when the stored agent cipher is `0`, SM2 when it is `1`. |
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
