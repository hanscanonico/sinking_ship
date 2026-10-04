# Deploying Sinking Ship to the mini PC

The online game (SH12) runs on the home mini PC as one Docker Compose stack,
`deploy/compose.yml`, reached only through a Cloudflare Tunnel — no port on the
machine is open to the network.

```
browser ──https──▶ Cloudflare ──tunnel──▶ cloudflared ──▶ proxy ──┬─▶ web     (the browser build)
                                                                 └─▶ server  (/ws, the game)
```

| Service | What it is |
|---|---|
| `server` | The exported Linux dedicated server (`make export-server`), run as `--server --bind=0.0.0.0` by a non-root user in a distroless image with no shell, its root filesystem read-only. Published on no port: only the proxy reaches it. |
| `web` | The browser build (`make export-web`) as static files behind nginx. Single-threaded, so it needs no cross-origin isolation headers. |
| `proxy` | nginx in front of both: `/` is the web build, `/ws` is upgraded to the game server. It keys every client on the `CF-Connecting-IP` header cloudflared forwards — trusted from cloudflared's fixed address (`10.247.47.6`) alone — an IPv4 client by its address and an IPv6 one by its /64, and holds each to **4 game connections at once** and **one new game connection every 10 s (6 at a go)**, and pages to 20 requests a second. The game server only ever sees the proxy, so this is the per-address limit (R9). Tune it in `deploy/proxy.conf`. Host-local on `127.0.0.1:8120` for checks. |
| `cloudflared` | The tunnel, reading its token from `deploy/.env`, at `10.247.47.6` on the `edge` network: outside the range Docker hands out by itself, so no other container takes it. |

Both images are built on the mini PC from the checkout by `deploy/Dockerfile`: an
export stage downloads Godot 4.7.1's Linux editor and export templates, checks them
against the SHA-512 sums in `deploy/.env`, and runs the repo's own `make import` and
`make export-server export-web`. Exports never ship the godot_ai editor helper (R11).

A page reaches the game on its own origin: `https://<hostname>/?create=1&name=Ada`
creates a room, `https://<hostname>/?room=ABCD&name=Bea` joins one. The page connects
to `wss://<hostname>/ws`.

## What is logged where

Players' addresses, page queries (`?room=…&name=…`) and user agents are logged
nowhere. Every container logs to Docker's json-file driver on the mini PC, capped at
5 × 10 MB per container and gone with the container.

| Service | What it logs |
|---|---|
| `server` | Who said hello, came and went — by display name and connection number (`Ada (peer 3)`) — each room by its code, every match's seed, transcript and timings. Never an address: it only ever sees the proxy's. |
| `proxy` | One line per request: time, method, path (never the query), status, bytes, duration. Its error log holds only what is critical, as nginx's every error line about a request names the client's address and the request line with its query. |
| `web` | No access log (every request comes from the proxy, its query with it), and only critical errors. |
| `cloudflared` | The tunnel's connections to Cloudflare. |

Room codes and display names stay on the host. `deploy/bin/deploy` prints container
logs only to a person at a terminal on the mini PC: run from the workflow
(`GITHUB_ACTIONS=true`), or with its output piped or redirected, it prints the
`docker compose … logs` command to run on the host instead, as the workflow's log is
public. To read them: `docker compose -f deploy/compose.yml logs <service>`.

## Not tested yet

These files were written on a machine without Docker and have never run. On the
first deploy, watch for:

- the export stage: the Godot download URLs and the template file names
  (`linux_release.x86_64`, `web_nothreads_release.zip`) inside the `.tpz`;
- the server starting in `gcr.io/distroless/base-debian12:nonroot` (the template
  links only glibc, 2.28 at most, checked on this machine) with a read-only root and
  its `user://` under the `/tmp` tmpfs;
- nginx-unprivileged starting with a read-only root (`/tmp` is its tmpfs);
- the `10.247.47.0/29` subnet of the `edge` network colliding with another network
  on the host (`docker network ls`; change it, its `ip_range`, `gateway` and
  cloudflared's `ipv4_address` here, and `set_real_ip_from` in `proxy.conf`, together);
- cloudflared at its fixed `ipv4_address` outside the network's `ip_range`, and
  starting with a read-only root, no capabilities and `/tmp` its only writable place
  (if it will not, its log says what it needed: drop `read_only` or add back the one
  capability, nothing more);
- in `proxy.conf`: `set_real_ip_from` the single address (check with `curl` from the
  host that `CF-Connecting-IP` is ignored there: a request from the host is keyed on
  the gateway's address); the `map` of `$binary_remote_addr` to `$limit_key` — its
  regex (checked with PCRE2 on 4- and 16-byte addresses, not in nginx) keeps an IPv6
  address's first 8 bytes; the limit zones keyed on it; `log_format anonymous` and the
  server's `access_log` and `error_log … crit`;
- in `web.conf`: `access_log off` and `error_log … crit` (the image's own
  `nginx.conf` sets the defaults these override);
- `--no-default-labels` in `deploy/bin/setup_runner` (runner versions before 2.300
  do not know it);
- the workflow's guard on `github.triggering_actor`, which no run has evaluated.

What was tested on the Mac: the four exports, the exported dedicated server hosting a
whole match for two exported clients (`make serve-local EXPORTED=1`), the browser
build joining a room in headless Chrome (`make serve-web-local`), and the game
server answering a WebSocket handshake on `/ws` with `101`, as `deploy/bin/deploy`
checks it. `deploy/bin/deploy`'s log guard ran with a stand-in for `docker compose`:
it printed the logs on a terminal alone, and not with `GITHUB_ACTIONS=true` or its
output piped. The Dockerfile's `: "${…:?}"` guard stops `sh` on either sum empty or
unset.

## Once, by hand

On the mini PC (`ssh mini-pc`), as the deploy user:

1. Clone the repo to `/home/mini-pc/Documents/sinking_ship`. The host needs docker
   with the compose plugin, `curl`, `jq` and `flock`.
2. `cp deploy/.env.example deploy/.env && chmod 600 deploy/.env`, then fill in:
   - `GODOT_EDITOR_SHA512` and `GODOT_TEMPLATES_SHA512`: from `SHA512-SUMS.txt` of
     <https://github.com/godotengine/godot-builds/releases/tag/4.7.1-stable>, the lines
     for `Godot_v4.7.1-stable_linux.x86_64.zip` and
     `Godot_v4.7.1-stable_export_templates.tpz`.
   - `CLOUDFLARE_TUNNEL_TOKEN`: in the Cloudflare dashboard, Zero Trust → Networks →
     Tunnels → Create a tunnel → Cloudflared, named `sinking-ship`; copy the token
     from the docker command it shows. Then add the tunnel's public hostname (for
     example `ship.vantage-ledger.com`) with service type **HTTP** and URL
     **`proxy:8080`**. WebSockets must be on for the zone (Network → WebSockets; on
     by default).
3. Deploy by hand once: `deploy/bin/deploy`. Then `curl -fsS
   http://127.0.0.1:8120/healthz`, and open `https://<hostname>/?create=1&name=Ada`
   in a browser: the room's code shows, with "Host: press Enter to start".

### The runner (optional)

The deploy workflow (`.github/workflows/deploy.yml`) runs on a self-hosted runner on
the mini PC, **by hand only** (`workflow_dispatch`). This repository is public, and
GitHub's advice is to keep self-hosted runners to private repositories: a pull
request from a fork runs the workflow files of its own branch, which can name any
runner label. Before registering the runner:

- Settings → Actions → General → "Approval for running fork pull request workflows
  from contributors": **Require approval for all external contributors**. Never
  approve a run you have not read.
- Keep every other workflow on GitHub's runners; the runner carries the label
  `sinking-ship-prod` alone, not `self-hosted`.
- Consider keeping the runner's service stopped between deploys
  (`sudo ~/actions-runner-sinking-ship/svc.sh stop`); a deploy by hand over ssh needs
  no runner at all.

Then: `deploy/bin/setup_runner "$(gh api -X POST
repos/hanscanonico/sinking_ship/actions/runners/registration-token --jq .token)"` and
the two `svc.sh` commands it prints.

## Deploying

- **From GitHub:** Actions → deploy → Run workflow, on `main`. The repository's owner
  only, a re-run too.
- **By hand:** `ssh mini-pc`, `cd ~/Documents/sinking_ship`, `deploy/bin/deploy`.

Either way `deploy/bin/deploy` fast-forwards the checkout, builds both images, swaps
`server`, `web` and `proxy`, and waits until the page and a WebSocket handshake on
`/ws` both answer through `127.0.0.1:8120`. A deploy restarts the game server:
matches being played end with it.

The server logs every room's tick time, each player's round trip and the snapshot
bandwidth every 10 s, and a finished match's transcript:
`docker compose -f deploy/compose.yml logs -f server`.

## Rolling back

Before building, `deploy/bin/deploy` tags the images that are serving as
`sinking_ship-server:previous` and `sinking_ship-web:previous`, and goes back to them
by itself when the new stack does not answer. To go back by hand:

```sh
docker image tag sinking_ship-server:previous sinking_ship-server
docker image tag sinking_ship-web:previous sinking_ship-web
docker compose -f deploy/compose.yml up -d --no-build server web proxy
```

The checkout stays on the new commit, so the next deploy builds it again: revert the
commit on `main` first to stay back.
