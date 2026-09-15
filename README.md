# Waiso — self-hosted

Run Python, TypeScript, JavaScript, C and C++ on your own infrastructure.

This repository holds the deployment files: a Compose file, a Helm chart and the
environment they need. Every service pulls a published image — there is nothing
to build.

---

## Docker Compose

```sh
git clone https://github.com/talissonjunior16/waiso.git
cd waiso
cp .env.example .env      # fill in the three required values

# Hosts that enforce AppArmor (Ubuntu, Debian, SUSE) — once per host:
sudo install -m 0644 apparmor/waiso-worker /etc/apparmor.d/waiso-worker
sudo apparmor_parser -r -W /etc/apparmor.d/waiso-worker

docker compose up -d
```

Open <http://localhost:8080>. The first account created on an empty database
becomes the Admin of the instance.

Not sure whether your host enforces AppArmor? `cat /sys/module/apparmor/parameters/enabled`
prints `Y` if it does. Skipping the profile there stops the worker from starting,
with an error naming it; on hosts without AppArmor there is nothing to install.

The three required values have no defaults on purpose; `.env.example` gives the
command that generates each one.

### Domains and HTTPS

To serve people on other machines, Waiso needs **three hostnames** — one per
service a browser talks to:

| Hostname (example) | Service | Host port |
|---|---|---|
| `waiso.example.com` | the web app | 8080 |
| `api.waiso.example.com` | the API | 3000 |
| `lsp.waiso.example.com` | the editor service (WebSocket) | 3001 |

1. **DNS.** Create an `A` record for each hostname pointing at the server's
   public IP (or a `CNAME` to a name that already does). Add `AAAA` records only
   if the server is reachable over IPv6.
2. **HTTPS.** Put a reverse proxy in front that terminates TLS. With
   [Caddy](https://caddyserver.com), which obtains certificates and passes
   WebSocket through on its own, the whole `Caddyfile` is:

   ```
   waiso.example.com     { reverse_proxy 127.0.0.1:8080 }
   api.waiso.example.com { reverse_proxy 127.0.0.1:3000 }
   lsp.waiso.example.com { reverse_proxy 127.0.0.1:3001 }
   ```

   Any other proxy works; the editor service needs WebSocket upgrades allowed.
3. **Tell Waiso the addresses.** In `.env`:

   ```sh
   WAISO_PUBLIC_UI_URL=https://waiso.example.com
   WAISO_PUBLIC_API_URL=https://api.waiso.example.com
   WAISO_PUBLIC_LSP_URL=wss://lsp.waiso.example.com

   # Only the proxy should reach these ports.
   WAISO_UI_PORT=127.0.0.1:8080
   WAISO_API_PORT=127.0.0.1:3000
   WAISO_LSP_PORT=127.0.0.1:3001
   ```

   then `docker compose up -d` again.

Binding the ports to `127.0.0.1` matters: Docker publishes ports through its own
firewall rules, so a port published on every interface is reachable from the
internet even when the host firewall blocks it.

Without the `lsp` hostname everything works except completions and diagnostics
in the code editor.

## Kubernetes

```sh
kubectl create secret generic waiso-db \
  --from-literal=DATABASE_URL='postgres://user:pass@db:5432/waiso'
kubectl create secret generic waiso-secrets \
  --from-literal=DB_CREDENTIALS_KEY="$(openssl rand -base64 32)" \
  --from-literal=SCRAPER_ENGINE_SECRET="$(openssl rand -hex 32)"

helm install waiso oci://ghcr.io/talissonjunior16/charts/waiso \
  --set postgres.existingSecret=waiso-db \
  --set credentials.existingSecret=waiso-secrets \
  --set ingress.enabled=true \
  --set ingress.hosts.ui=waiso.example.com \
  --set ingress.hosts.api=api.waiso.example.com \
  --set ingress.hosts.lsp=lsp.waiso.example.com
```

The same three hostnames as above, served by your ingress controller: create a
DNS record for each pointing at the controller's external address
(`kubectl get ingress`), and set `ingress.tls.enabled=true` with a certificate
for all three (or your cert-manager annotations under `ingress.annotations`).
Most controllers pass WebSocket through for the `lsp` host; some need an
annotation for it.

The chart expects a PostgreSQL you already run; it does not bundle one. See
[`helm/waiso/values.yaml`](helm/waiso/values.yaml) for every option.

On nodes that enforce AppArmor (Ubuntu, Container-Optimized OS, SUSE), load
[`apparmor/waiso-worker`](apparmor/waiso-worker) on each node the worker can run
on and add `--set worker.appArmorProfile=waiso-worker` (Kubernetes 1.30+).
Without it every Python, C and C++ run fails; the worker logs the reason at startup.

---

## What runs

| Service | What it does | Required |
|---|---|---|
| `ui` | The web app your users open | yes |
| `api` | The HTTP API; applies its own migrations on startup | yes |
| `worker` | Runs your scripts and flows | yes |
| `sql-worker` | SQL scripts and the database workbench | yes |
| `image-worker` | Image processing | yes |
| `scraper-engine` | AI Scrapers | only if you use them |
| `lsp` | Completions and diagnostics in the editor | no |
| `postgres` | The database | unless you bring your own |

To scale out, start more workers with the same `.env` on any machine that can
reach the database. Workers need no inbound port, and each one appears on the
Workers page.

## Licensing

**Evaluation.** A new instance runs fully for **14 days** — no license needed to
start. **Settings → License** shows how many days are left.

**Getting a license.** Send us the instance ID shown in **Settings → License** and
the number of seats you need. You receive two things: a **license token** and a
**check-in key**. Paste both into **Settings → License** and apply. A license is
bound to that instance ID and will not install anywhere else.

**Check-ins.** A licensed instance checks in with `https://api.waiso.com.br` every
hour, so it needs outbound HTTPS to that address. If it cannot check in for
**2 days**, it enters **grace mode**:

- everything stays readable — projects, scripts, flows, results, logs;
- you can still install a license;
- **nothing new runs** — not from the editor, schedules, API endpoints or MCP —
  and nothing saves or publishes.

No data is deleted or withheld, and grace clears itself the moment a check-in
succeeds. The same happens when the evaluation ends without a license.

**Offline licenses.** For networks with no route to the internet, **Enterprise**
can be licensed offline: no check-ins, valid until its expiry date.

**Pricing** is per seat, not per run: runs, projects, schedules and integrations
are unlimited. A seat is any account that can do more than read; viewers are
free and never counted.

## Upgrading

```sh
# Compose — set WAISO_VERSION in .env first, or leave it unset for this release
docker compose pull && docker compose up -d

# Kubernetes
helm upgrade waiso oci://ghcr.io/talissonjunior16/charts/waiso --reuse-values
```

Migrations run automatically when the new API starts. Back up the database
first: there is no downgrade path.

## Back up two things

1. **The database** — everything you have made.
2. **`DB_CREDENTIALS_KEY`** — without it, a restored database holds credentials
   nobody can decrypt, and the license has to be applied again.

Keep the key somewhere other than the machine it runs on.

## Support

Documentation: <https://waiso.com.br/docs/self-host> · Issues in this repository
are for deployment problems.
