# Example agent config

These TOML files are the OpenNHP docker demo, copied so the schema is easy to read. They are not a production config.

- `config.toml` uses the published demo agent key and `DefaultCipherScheme = 1` (SM2).
- `server.toml` points at docker addresses `177.7.0.9` and `177.7.0.14` on UDP `62206`. A phone cannot reach those addresses.
- `resource.toml` knocks auth service `example`, resource `demo`, cluster `demo-cluster`.
- `dhp.toml` holds a published demo TEE key. Omit it unless you use that protocol.

Generate a new key with `generateKeys`, write your own `etc/config.toml`, and point `server.toml` or `addServer` at your nhp-server. The field guide is [docs/configuration.md](../docs/configuration.md).
