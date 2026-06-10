# baseproof CLI

The unified **baseproof** client — one binary, bound to **one network** by a
client bundle (or the active network). All logic lives in the published
`github.com/baseproof/tooling/libs/cli` module; this repository is the thin
Cobra binary over it (extracted from `tooling/baseproof-cli`).

## Build, install, verify

```sh
make build            # ./bin/baseproof, version stamped from `git describe`
make install          # install `baseproof` into GOBIN (go env GOBIN, else GOPATH/bin)
make check            # gofmt + go vet + go test
baseproof --version   # verify the installed binary
```

The Makefile pins the binary name: a bare `go install github.com/baseproof/cli@latest`
works but names the binary `cli` (the module path's last element). The libs
dependency is a private baseproof module — the Makefile exports
`GOPRIVATE=github.com/baseproof/*`; set it yourself for bare `go` commands.

Builds are `CGO_ENABLED=0`: one static binary per platform, no libc
dependency — linux (any distro, glibc or musl) and macOS (Intel + Apple
Silicon), amd64 + arm64. Tagging `vX.Y.Z` publishes prebuilt binaries,
completions, man pages and sha256 checksums as a GitHub release
(`.github/workflows/release.yml`); CI proves the same matrix on every push.

## Generate completions + man pages

```sh
make completions      # bash / zsh / fish / powershell into ./completions
make man              # man pages into ./man/man1
baseproof docs --format markdown --dir docs   # markdown command reference
make cross            # release binaries into ./dist (linux, darwin, windows)
```

Both generators render the live command tree — `baseproof completion <shell>`
and `baseproof docs` ship in the binary itself — so completions and docs can
never drift from the shipped surface.

## Homebrew

```sh
brew install baseproof/tap/baseproof   # macOS (Intel + Apple Silicon) and Linux
```

Tagging `vX.Y.Z` runs GoReleaser (`.goreleaser.yaml`): it publishes the GitHub
release and pushes the regenerated cask — binary + shell completions + man
pages, per-platform URLs + sha256 — to `baseproof/homebrew-tap`
(`Casks/baseproof.rb`).

One-time setup: create the `baseproof/homebrew-tap` repository and add a
`HOMEBREW_TAP_TOKEN` Actions secret here (a PAT with write access to the tap).
Without the secret a release still publishes — the cask is generated in the
release workspace but not pushed.

## Commands

| Command | What it does |
|---|---|
| `baseproof submit` | Submit ONE entry to the network: a new entity, a same-signer **amendment** (`--amend <seq>`), a **delegation** (`--delegate-to`), or a **delegated amendment** (`--amend`+`--delegation`). |
| `baseproof proof` | Generate a **v2 self-anchored proof** of an entry (`--seq`), self-verify it offline, and (`--out`) write a portable file. |
| `baseproof verify <file>` | Verify a v2 proof **fully offline** (zero network): recompute witness K-of-N, inclusion, SMT membership — fail-closed. Network-agnostic; `--pin`/`--network`/`--bundle` binds it to a network you trust. |
| `baseproof info` | Understand a network in one view: identity (recomputed), trust root, witnesses + K-of-N, auditors (live + in-sync), horizon, admission, accepted messages, anchors/labels/endpoints, mirrors, federation. `--verify` recomputes the crypto; `--federation [--depth N]` walks + verifies the cited peers (bounded, cycle-guarded). |
| `baseproof witnesses` | The witness set — current, or as-of a historical tree size (`--at N`, time-travel); labels overlaid. |
| `baseproof network` | gcloud-style network store: `add` (author a bundle from a live ledger — `--from-ledger <url> --quorum K [--ca-cert]` — or import `--from <file\|url>`), `list`, `use`, `show`. |
| `baseproof config` | `config set network <name>` / `config list` — the active-network default (`~/.config/baseproof/`). |
| `baseproof load` | Drive the memory-bounded loadgen engine (`-n`, `--amend-ratio`, `--delegate-ratio`, `--workers`, `--batch-size`, `--seed`) and optionally stream the expected-state oracle (`--manifest oracle.jsonl`). |
| `baseproof completion <shell>` | Generate shell completions (bash, zsh, fish, powershell) from the live command tree. |
| `baseproof docs` | Generate the command reference — man pages (`--format man`) or markdown (`--format markdown`) — into `--dir`. |

## Design

- **One network per bundle.** A `clientbundle` (`--bundle <file>` or a stored
  `--network <name>`, else the active network) carries the endpoint, the trust
  root (network id, quorum K, content-addressed bootstrap hash), the destination
  log DID, the accepted message catalog, and the TLS transport posture
  (server-verify CA-pin / mTLS / plaintext).
- **Zero-Trust by default.** Nothing the server says is trusted: `info --verify`
  recomputes the network id from the served bootstrap and the K-of-N cosignatures
  against the genesis witness set; `proof` self-verifies offline before it emits;
  `verify` recomputes every cryptographic check and fails closed.
- **Standalone proofs.** A v2 proof is self-contained — it embeds its genesis
  bootstrap + witness set + network id — so `verify` needs no ledger and no
  network. `--pin` binds the proof's network id to one you already trust.
- **The logic is the library.** Every command is a `libs/cli` `RunX(ctx, args)`
  function; the platform e2e (`tooling/e2e`) drives the same functions against a
  real fleet, so the shipped surface is exactly what is tested.

### Cobra surface
Each command is a `cobra.Command` with native POSIX flags + shell completion +
per-command help (`main.go` + `commands.go`). A generic forwarder reconstructs the
flags a user **set** into the `--name=value` args the `libs/cli` `RunX` seams parse
(`cmd.Flags().Visit` → only changed flags; unset flags fall through to `RunX`'s own
defaults), so defaults + logic stay in `libs/cli` **untouched** and the platform
e2e drives exactly what ships. `cli.Main` (the stdlib-`flag` dispatch) remains in
libs for embedders.
