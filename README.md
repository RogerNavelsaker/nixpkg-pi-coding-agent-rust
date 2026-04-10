# nixpkg-pi-coding-agent-rust

Thin Nix packaging repo for [`Dicklesworthstone/pi_agent_rust`](https://github.com/Dicklesworthstone/pi_agent_rust).

## Upstream

- Repo: `Dicklesworthstone/pi_agent_rust`
- Vendored source: [`upstream/`](/home/rona/Repositories/@nixpkgs/nixpkg-pi-coding-agent-rust/upstream)
- Upstream crate version: `0.1.10`
- Vendored commit: `be52f4762ff0a42d99d540bdc651415729a0a5b4`

## Usage

```bash
nix build
nix run
```

The package installs the Rust-native `pi` CLI from vendored source.
