# Security audit — RoadSOS (+ ML integration)

**Method.** Static review of every backend route, the new ML module, both front
ends and configuration files; secret-pattern scan over all backend/dashboard/app
source (0 matches); `git check-ignore` verification for secret/model paths; live
testing of the authn/limit/error paths (see `docs/testing.md` §2/§4/§5).
Pre-existing issues are marked *(pre-existing)* — they are reported, not
silently "fixed" by changing behaviour the demo depends on.

Severity: **High** = exploitable now · **Medium** = exploitable under common
misconfiguration · **Low/Info** = hardening.

---

## Findings

| ID | Severity | Status | Finding |
|---|---|---|---|
| F1 | High | **Fixed (safe default)** *(pre-existing)* | `python app.py` hardcoded `debug=True` on `0.0.0.0:5000`. The Werkzeug interactive debugger can execute code, and auto-reload restarts the demo server. |
| F2 | High | **Accepted, documented** *(pre-existing)* | Command-centre REST endpoints have **no authentication** (`/incidents`, `/update-status`, `/dispatch`, `/helper/*`, `/demo/*`). |
| F3 | Medium | **Accepted, warned** *(pre-existing)* | CORS defaults to **any origin** when `ALLOWED_ORIGINS` is unset (startup warning, also applied to Socket.IO). |
| F4 | Medium | **Accepted, documented** *(pre-existing)* | Rate limiting exists only on `/api/v1/predictions/*`. `/demo/simulate` can generate data. Limiter keys on `request.remote_addr`, so behind a reverse proxy all clients share one bucket. |
| F5 | Low | **Documented** *(pre-existing)* | The limiter is in-memory and per process; extra workers multiply the effective limit. |
| F6 | Low | **Fixed** | `ROADSOS_API_KEY` was compared with `!=` (timing-leaky). |
| F7 | Low | **Fixed** | `.env` was documented (`copy .env.example .env`) but **never read** by the app — no code loaded it. |
| F8 | Info | **Fixed** | `.env.example` shipped `FLASK_DEBUG=1`. |
| F9 | Info | **Verified clean** | Secret hygiene: no key material in source, no `.env`/`serviceAccountKey.json`/keys in the tree, model + secrets gitignored. |
| F10 | Info | **Mitigated by design** | Loading a `.pkl` is arbitrary code execution if the file is tampered with. |
| F11 | Info | **By design** | Prediction input surface is strictly validated (allowlists, ranges, 1 MB cap). |
| F12 | Info | **By design** | ML endpoints are advisory-only and can never change incident state. |

---

## F1 — Werkzeug debug on a public bind *(pre-existing, now off by default)*

**Was:** `socketio.run(app, host='0.0.0.0', port=5000, debug=True, allow_unsafe_werkzeug=True)`.
**Risk:** anyone who can reach the port and trigger an exception gets an
interactive debugger that can run code; the reloader also restarts the process.

**Now (`backend/app.py`):**

* `FLASK_DEBUG` defaults to **0** — the debugger is off unless explicitly
  enabled, and enabling it logs a loud warning naming host and port.
* `use_reloader=False` is passed **explicitly**: no file watcher and no silent
  restarts mid-demo. Verified three ways: the startup log says
  `reloader=off`, there is no "Restarting with stat" line, and killing the
  worker process stops the server instead of having it respawned.
  *(Aside: this machine's venv `python.exe` is a launcher that re-executes the
  base interpreter, so **every** script in this venv appears as two
  `python.exe` entries in Task Manager. A control run of a plain
  `python -c "time.sleep(6)"` doubles the same way — so a process count is not
  evidence about Flask.)*
* The effective configuration is logged at startup
  (`Serving on http://0.0.0.0:5000 (FLASK_DEBUG=0, reloader=off)`).
* `RUN_HOST` / `RUN_PORT` are overridable (`RUN_HOST=127.0.0.1` behind a
  reverse proxy). The default stays `0.0.0.0` **only** so a physical phone can
  join a LAN demo — change it when the server is internet-facing.
* Documented in `.env.example` with the reasoning.

## F2 — no authentication on command-centre endpoints *(pre-existing, accepted)*

Every legacy route is open to whoever can reach the port: anyone can create or
update incidents, dispatch units, or seed demo data. The mobile app and
dashboard have no auth plumbing, so adding auth here would break the product as
shipped; that is why this is **reported rather than changed**.

Mitigations that already exist / are recommended:

* `firestore.rules` (reviewed, unchanged) requires Firebase auth for direct
  client access to `incidents`, `helpers`, and `missions`, and restricts
  updates to the owner or an `ADMIN`.
* Run the backend on a trusted LAN/VPN, or put an authenticating gateway in
  front (API key, mTLS, or reverse-proxy basic auth).
* Disable demo routes in production (`/demo/simulate`, `/demo/clear`).
* The **new** ML endpoints are the only ones with optional key auth
  (`ROADSOS_API_KEY`, `X-API-Key` or `Bearer`, constant-time compare, 401
  `UNAUTHORIZED`) — see F6.

## F3 — permissive CORS default *(pre-existing, warned)*

`ALLOWED_ORIGINS` unset ⇒ `CORS(app)` + `socketio.init_app(...,
cors_allowed_origins="*")`, plus a startup warning telling you to restrict it.
Set it explicitly in production:

```
ALLOWED_ORIGINS=https://dashboard.example.com
```

Credentials are **not** allowed (`supports_credentials=False`) even when the
list is explicit.

## F4 — uneven rate limiting *(pre-existing, documented)*

* Predictions: 60/min/IP (configurable), 429 + `Retry-After` — verified live
  (56×200 then 14×429 while `/health` and `/incidents` stayed 200).
* Everything else: unbounded. `/demo/simulate` in particular is a cheap way to
  create records.
* Limiter key is `request.remote_addr`: with a reverse proxy the source IP is
  the proxy, so all users share one bucket. Fix with a gateway limit or
  `ProxyFix` + trusted proxy headers — not configured here (unknown
  deployment topology).
* Socket.IO connection counts are likewise unbounded *(pre-existing)*.

## F6 — API-key comparison *(fixed)*

```python
# before: if provided != _api_key:          # leaks equality byte-by-byte
# now:    if not hmac.compare_digest(provided.encode(), _api_key.encode()):
```
Covered by the existing tests (wrong key ⇒ 401, correct key ⇒ 200).

## F7 — `.env` was never loaded *(fixed)*

`.env.example` told users to copy it to `.env`, but no code read it (Flask's
`load_dotenv` requires `python-dotenv`, which is not installed). Added a
~20-line dependency-free loader (`backend/app.py::_load_env_file`) that:

* runs **before** any module reads `os.environ` at import time;
* **never overrides** an already-set variable (shell/CI wins — the same rule
  python-dotenv uses);
* skips comments/blank lines, strips matching quotes, and treats a missing file
  as a no-op.

Verified by `backend/tests/test_env_loader.py` (4 tests).

## F9 — secret hygiene *(verified clean)*

| Check | Evidence |
|---|---|
| Key patterns (`AIza…`, `sk-…`, private-key blocks, `password=`/`api_key=` literals) in backend/dashboard/app source | **0 matches** |
| `.env`, `serviceAccountKey.json`, `*.pem`, `*.p12` anywhere in the tree | **none** (only `.env.example`) |
| `git check-ignore` → `models/road_accident_model.pkl` | **IGNORED** |
| `git check-ignore` → `backend/.env` | **IGNORED** |
| `git check-ignore` → `backend/serviceAccountKey.json` | **IGNORED** |
| Model visible in `git status --ignored` | `!! models/road_accident_model.pkl` (tracked: no) |
| `.env.example` / docs contain only placeholders and public hashes | reviewed |

The Firebase key path is env-driven (`FIREBASE_SERVICE_ACCOUNT_KEY`) and its
absence is a non-fatal warning — no key is required to run the system.

## F10 — pickle supply chain *(mitigated, documented)*

`road_accident_model.pkl` is executable Python. Mitigations in place:

1. downloaded only from the pinned Hugging Face revision
   `c4a7daf40b05e506c3c00aca7c8ab00bc00db53c`;
2. expected **size** (1,965,071,297 B) and **SHA-256**
   (`B9E5BE…E98B2`) verified *before* the object is unpickled; health reports
   `sha256Verified: true`;
3. the path comes from configuration only (`MODEL_PATH`/cache dirs) — **never**
   from a request;
4. `.env.example` now says to keep `MODEL_SHA256` set, because emptying it
   disables the check.

Residual: anyone who can write `models/road_accident_model.pkl` **and** change
`MODEL_SHA256` can execute code as the backend user — filesystem permissions are
the boundary (documented, out of app scope).

## F11 — prediction input surface *(by design)*

* `Content-Type` must be JSON; malformed JSON ⇒ 400 `INVALID_JSON`.
* Bodies capped by `MAX_CONTENT_LENGTH` (1 MB default).
* Unknown feature keys are **rejected** (not silently dropped).
* Categories are checked against allowlists derived from training data; numerics
  against ranges (`Hour 0–23`, `Year 1900–2100`, legal lat/lon, `Speed_limit`
  ∈ {10,15,…,70}). No value is ever interpolated into a path, query, shell or
  SQL — the encoded vector goes straight into `predict()`.
* Both clients now enforce the published ranges/speed set before sending, so
  most bad input never reaches the server (and the server still re-validates).

## F12 — ML is advisory and isolated *(by design, tested)*

* `severityPrediction` is written to a fixed field map; `status`,
  `dispatchedResources` and escalation are never touched (`test_safety.py`).
* No prediction gates a countdown, dispatch or notification.
* When the model is broken the endpoints fail closed with 503
  `MODEL_UNAVAILABLE` while `/health`, `/incidents`, `/dispatch` keep answering
  (verified live while predictions were rate-limited).

---

## Production checklist (not all applicable to a demo)

- [ ] `ALLOWED_ORIGINS` set to the real dashboard origin (F3)
- [ ] `RUN_HOST=127.0.0.1` behind a reverse proxy; TLS terminated at the proxy
- [ ] `FLASK_DEBUG` left at `0` (F1)
- [ ] `ROADSOS_API_KEY` set if predictions are reachable beyond localhost (F6)
- [ ] Gateway-level auth for the command-centre API (F2) or keep it LAN-only
- [ ] Gateway-level rate limits for non-ML routes; disable `/demo/*` (F4)
- [ ] Single worker (or shared limiter state) so the 60/min limit means 60/min (F5)
- [ ] `MODEL_SHA256` left set; `models/` and `.env` kept out of git (F9/F10)
- [ ] `serviceAccountKey.json` provisioned out-of-band, `chmod 600`-style perms
