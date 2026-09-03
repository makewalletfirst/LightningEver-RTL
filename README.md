# LightningEver RTL

LightningEver-flavoured fork of **[Ride The Lightning](https://github.com/Ride-The-Lightning/RTL) v0.15.8** — the operator GUI for **LightningEver**, a Lightning Network LSP built on **BitEver L1**. This fork is shipped on the `260530` branch.

It is the **operator-only** companion to the public **[LightningEver Explorer](https://github.com/makewalletfirst/LightningEver-Explorer)**:

| | LightningEver RTL | LightningEver Explorer |
|---|---|---|
| Audience | the LSP operator only | the public |
| Scope | full control — open / close channels, sign, wallet | read-only summary of node + channels |
| Auth | password + ideally VPN | none, behind 20 s cache |
| Default port | **3008** | 3009 |

> ⚠ Hold all credentials of the LSP. Keep this UI behind a VPN or IP allow-list. Never put it on a public domain.

---

## What this fork changes

| | Upstream RTL | This fork |
|---|---|---|
| Page title | `RTL` | **`LightningEver RTL`** |
| Favicon / OG image | RTL default | LightningEver brand mark |
| Dashboard "Chain" pill | `Bitcoin Mainnet` | **`BitEver Mainnet`** |
| Display units (ECL screens) | `Sats` / `BTC` | **`ever`** / **`BEC`** |
| `Sample-RTL-Config.json` | LND-default, plaintext `multiPass` | ECL-prewired, `multiPassHashed` only |
| Default port in sample | 3000 | **3008** |
| Dockerfile | rebuilds Angular from source inside the image (~1.4 GB) | installs prod deps only on top of the committed pre-built `frontend/` (~250 MB) |
| GitHub Actions | only on `v*` tags & releases | also on every push / PR to `260530` / `main` |

All other behaviour — channel manager, on-chain wallet, peers, routing, signing — is upstream RTL.

---

## Quick start

### A. Bare-metal (Node + PM2)

```bash
git clone -b 260530 https://github.com/makewalletfirst/LightningEver-RTL.git
cd LightningEver-RTL
npm ci --legacy-peer-deps          # upstream Angular peer-dep churn
cp Sample-RTL-Config.json RTL-Config.json
$EDITOR RTL-Config.json            # see § Configuration below

node rtl.js                        # foreground

# or with PM2
pm2 start rtl.js --name LN-RTL --time --max-restarts 5
pm2 save
```

Smoke test:

```bash
curl -sI http://127.0.0.1:3008/    # → 200 OK
```

### B. Docker

```bash
docker pull silverruler/lightningever-rtl:260530

docker run -d --name lightningever-rtl \
  --restart unless-stopped \
  -p 3008:3008 \
  -v /etc/lightningever/RTL-Config.json:/RTL/RTL-Config.json \
  -v /etc/lightningever/rtl-db:/RTL/db \
  -v /etc/lightningever/rtl-backups:/RTL/backups \
  silverruler/lightningever-rtl:260530
```

The image holds **no credentials**. You supply `RTL-Config.json` via a bind mount, and it must be mounted **read-write** — RTL writes a session encryption key back into the file on first start. A `:ro` mount crashes with `EROFS`.

### C. Docker Compose

```yaml
services:
  rtl:
    image: silverruler/lightningever-rtl:260530
    container_name: lightningever-rtl
    restart: unless-stopped
    ports:
      - "3008:3008"
    volumes:
      - ./RTL-Config.json:/RTL/RTL-Config.json
      - ./db:/RTL/db
      - ./backups:/RTL/backups
```

---

## Configuration

Copy `Sample-RTL-Config.json` to `RTL-Config.json` and fill in the four operator-specific fields:

| Field | Example | Description |
|---|---|---|
| `port` | `"3008"` | TCP port RTL listens on |
| `nodes[0].authentication.lnApiPassword` | `"…"` | eclair `api.password` from `eclair.conf` |
| `nodes[0].settings.lnServerUrl` | `http://<lsp-host>:8085` | eclair JSON-RPC endpoint |
| `multiPassHashed` | `"dc79a4…"` | SHA-256 hex of your operator password — **never store plaintext** |

Compute the password hash once and paste only the hex:

```bash
printf '%s' 'your-operator-password' | sha256sum
# → dc79a46256405888609f702ac3977aad7585f0a93c6649349ee98f85a5c1836d  -
```

`RTL-Config.json` is `.gitignored`, so credentials never reach this repo.

---

## Reverse proxy (operator-only — keep private)

```nginx
server {
  listen 443 ssl http2;
  server_name rtl.internal.example;       # private DNS or /etc/hosts only
  allow 10.8.0.0/24;                      # your VPN subnet
  deny  all;

  location / {
    proxy_pass         http://127.0.0.1:3008;
    proxy_http_version 1.1;
    proxy_set_header   Upgrade           $http_upgrade;
    proxy_set_header   Connection        "upgrade";
    proxy_set_header   Host              $host;
    proxy_set_header   X-Forwarded-For   $remote_addr;
    proxy_set_header   X-Forwarded-Proto $scheme;
  }
}
```

WebSocket upgrade is required (RTL streams events).

---

## Building the Angular frontend (only if you touch `src/`)

This branch ships `frontend/` and `backend/` **pre-built** so a fresh clone runs without any Angular toolchain. Only rebuild when you change `src/`:

```bash
npm run buildfrontend     # ng build --configuration production
npm run buildbackend      # tsc for the Express backend
```

---

## CI

Two GitHub Actions workflows run on every push / PR to `260530` and `main`:

| Workflow | What it does |
|---|---|
| **LightningEver CI** | builds Angular + backend on Node 22, asserts that `LightningEver RTL` title and OG meta survive the build |
| **LightningEver Docker** | builds the Docker image; if `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` repo secrets are present, also pushes `silverruler/lightningever-rtl:<branch>`, `:sha-<7>`, and `:latest` (on `main`) |

The four upstream RTL workflows (only triggered by `v*` tags and releases) are left in place untouched.

---

## License

Upstream RTL is MIT-licensed; this fork remains MIT. See `LICENSE`.
