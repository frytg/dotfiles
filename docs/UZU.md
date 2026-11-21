# UZU.md

[uzu](https://github.com/trymirai/uzu) is Mirai's local inference engine for Apple silicon. It runs a Metal backend, uses speculative decoding, and serves an OpenAI-compatible API. Recipes live in [`just/uzu.just`](../just/uzu.just). We build it from source because there is no Homebrew formula or prebuilt CLI.

## Install

Run `just uzu-install` (aliases: `install-uzu`, `uzu-update`). It clones into `../_cli/uzu` next to the dotfiles repo (override with `UZU_DIR`), downloads the Metal toolchain if needed, and runs `cargo build --release -p cli`. A rerun pulls and rebuilds.

- **Skip `cargo tools setup`.** The README suggests it, but it also installs uv, pnpm, and other tools that brew and mise already manage. `rust-toolchain.toml` pins a nightly toolchain, and rustup installs it on the first `cargo` call.
- **Metal toolchain is a separate Xcode component.** `xcrun -f metal` finds the binary even when the toolchain is missing, so the build script fails with `cannot execute tool 'metal' due to missing Metal Toolchain`. `xcodebuild -downloadComponent MetalToolchain` (about 840 MB) fixes it. The recipe checks `xcrun metal --version`, which actually runs the tool.
- **Release build takes about a minute** on an M5 Pro after the first dependency compile.

## Models

uzu reads only its own model format. It downloads catalog models on first use into `~/.cache/mirai/models/mirai/<model-slug>/`. `just uzu-models` lists the catalog. Pass a Hugging Face ID (`trymirai/Qwen3.8-27B-L`) or a local model directory as `--model`.

- **Default is `trymirai/Qwen3.8-27B-L`** (configured via `UZU_MODEL` in [`just/uzu.just`](../just/uzu.just)). `-M` checkpoints are Mirai's medium quantization (likely 4-bit; `Qwen3.6-27B-M` was about 15 GB), and `-L` checkpoints are the large quantization (likely 8-bit; `Qwen3.6-27B-L` was 28.8 GB). Override per shell with `UZU_MODEL`.
- **oMLX models don't load.** `~/.omlx/models/Jundot/*-oQ8e-mtp` are MLX safetensors with oMLX's own mixed-bit quantization and separate `.scales` tensors. uzu can't read them, and Mirai's converter, [lalamo](https://github.com/trymirai/lalamo), has no importer for oQ8e.
- **35B-A3B MoE needs a conversion.** lalamo has a spec for `Qwen/Qwen3.6-35B-A3B`, but only from the bf16 HF weights (about 70 GB download, tight on 64 GB RAM). Mirai's catalog has no prebuilt MoE checkpoint. We haven't tried this.

## Running

- `just uzu`: interactive TUI chat. Extra args go to the CLI, e.g. `just uzu --reasoning-effort disabled`.
- `just uzu-ask "…"`: one message, streamed reply, then a stats box (TTFT, prefill and generation t/s, memory, energy).
- `just uzu-serve [port]`: `POST /v1/chat/completions` (streaming) and `GET /v1/models` on `127.0.0.1:8000`. oMLX uses 11223, so the ports don't clash. Prefix caching is on by default. Server logs go to `~/.cache/mirai/server/logs/`.
  - `/v1/models` reports the catalog ID (`alibaba:qwen3.6:27b:mirai:mirai-m:4`), not the HF ID.
  - Qwen3.6 reasons by default, and `server` has no `--reasoning-effort` flag. Thinking comes back in `reasoning_content`, so a small `max_tokens` can use up the budget and return an empty `content`.

## Tailnet HTTPS

`just uzu-tailscale` publishes the local server as the Tailscale Service `svc:uzu` at `https://uzu.<tailnet>.ts.net:8000`. Clients use `…:8000/v1` as the OpenAI base URL. The service has its own virtual IP, so HTTPS on 8000 doesn't clash with uzu listening on `127.0.0.1:8000`. `just uzu-tailscale-off` drains and clears it.

- **The serve config persists.** tailscaled stores it, so it survives reboots. But it only proxies. While `just uzu-serve` isn't running, requests get a 502.
- **Services need a tagged host and admin approval.** The Mac carries `tag:devices`. The first run registers the host as pending. Approve it on the admin console's Services page (define `svc:uzu` with `tcp:8000` there if it doesn't exist yet), or add an `autoApprovers.services` entry for the tag in the policy file.
- **No auth on uzu.** Tailnet ACLs and grants decide who can reach `svc:uzu`.

## Measured

Qwen3.6-27B-M on an M5 Pro with 64 GB, `--reasoning-effort disabled`, short prompt, November 2026:

- 44 t/s generation, 27 t/s prefill, 0.79 s to the first token
- 3.47 tokens per forward pass from speculative decoding
- 14.8 GB memory

Mirai's catalog lists 145 t/s for the same model, but that was measured on an M5 Max with 128 GB.
