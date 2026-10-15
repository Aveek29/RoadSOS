# Presentation → Implementation Requirements Trace

**Source artifact:** `Project.pptx` (12 slides) — *"Road Accident Monitoring and Emergency Response System"*, Meerut Institute of Engineering & Technology, July 2026.
**Extraction method:** slide XML text extracted directly from the `.pptx` container (every `<a:t>` run, slides 1–12). Text below is quoted from that extraction, not paraphrased.
**Repository audited:** this repo (`roadsos/`, branches at the time of writing: uncommitted working tree).

| Legend | Meaning |
|---|---|
| **MET** | Stated requirement is present in the code and verified by an executed test/observation. |
| **PARTIAL** | Present but differs in detail from the slide, or only partly exercised. |
| **NOT IMPLEMENTED** | Stated in the slide, absent from the code. |
| **BLOCKED** | Cannot be verified with the tools available in this environment. |
| **TARGET** | Slide states an expected metric/goal; no measurement exists anywhere in the repo, so it is treated as a target, **not** as a result. |

---

## 1. Slide-by-slide trace

### Slide 1 — Title
> "Road Accident Monitoring and Emergency Response System", authors, MIET Meerut, AKTU Lucknow, July 2026.

Identity/metadata only. **No requirements.** Nothing to verify.

### Slide 2 — Introduction
| Requirement as stated | Where it lives in the repo | Verification | Status |
|---|---|---|---|
| Automatically detect accidents using smartphone sensors | `app/lib/accident_detection/engine/detection_engine.dart`, `engine_builder.dart`, `main.dart` (builds `globalDetectionEngine`) | Code read; no executed Dart test (Flutter toolchain — see §4) | **MET** (impl.) / unverified at runtime |
| Initiate emergency assistance **without any user interaction** | `main.dart` wires `EmergencyService.listen()`; `emergency_handling/emergency_service.dart` | Static read of the wiring | **MET** (impl.) |

### Slide 3 — Literature Review
Ten cited papers and their stated gaps (single-sensor false alarms, no volunteer network, CCTV blind spots, no GPS streaming, etc.). **No product requirements** — these are the motivations that slides 4–8 answer.

### Slide 4 — Paradigm shift: Legacy vs Proposed RoadSOS
| Requirement as stated | Implementation | Verification | Status |
|---|---|---|---|
| 100% zero-interaction detection | `accident_detection/` engine + `main.dart` bootstrap | Static | **MET** (impl.) |
| Multi-Sensor Fusion: Accel + Gyroscope + GPS Speed | `accident_detection/services/sensor_service.dart` (accelerometer + gyroscope), `analyzers/motion_analyzer.dart`, `analyzers/orientation_analyzer.dart`, `context_awareness/speed_monitor.dart` | Static | **MET** (impl.) |
| 10s grace window, user can cancel an accidental drop | `emergency_handling/countdown_manager.dart` — `CountdownManager({this.durationSeconds = 10})` | Static (default **is** 10s) | **MET** |
| Continuous streaming: real-time WebSocket tracking link | `services/live_tracking_service.dart`, `services/socket_service.dart` (`emitUpdateLocation`), backend `@socketio.on('update_location')` | Static | **MET** (impl.) |
| Geohashed network alerts nearby Good Samaritans | `helper_network/geohash_service.dart`, `radius_search_engine.dart`, `location_index_service.dart`, `notification_service.dart`; backend `helper_respond` → `helper_accepted` | Static | **MET** (impl.) |
| Police Dashboard: centralized React command portal | `frontend_dashboard/` (React) — **Create React App** build | `npm run build` → *Compiled* (executed) | **PARTIAL** — see deviation D1 (slide 10 says *Vite*) |
| Authority monitoring / dispatch from dashboard | `frontend_dashboard/src/App.js`, `services/api.js` (`dispatch`, `updateStatus`), backend `@socketio.on('dispatch_resource')` | Static | **MET** (impl.) |
| Static one-time SMS coordinate link (legacy column) | replaced by live streaming in this repo | — | n/a |

### Slide 5 — Research Gaps
Restates problems (victims unconscious, single-sensor false alarms, no responder/volunteer integration, no authority monitoring). **No new requirements**; each gap maps to the slide-4 row that closes it.

### Slide 6 — Challenges
| Challenge as stated | How this repo addresses it | Status |
|---|---|---|
| Accurate detection without false positives | three-factor verification (`analyzers/`: motion + orientation + inactivity) + 10s cancel window | **MET** (impl., no accuracy measurement in repo) |
| Reliable real-time location sharing | `live_tracking_service.dart`, Socket.IO `update_location` | **MET** (impl.) |
| Fast communication with emergency contacts | `emergency_handling/sms_service.dart` (launches `sms:` URI via `url_launcher`), `firestore_service.dart` | **PARTIAL** — see deviation D4 |
| Coordination with volunteers and police | `helper_network/` + dashboard | **MET** (impl.) |
| Privacy and data security during emergencies | `firestore.rules`; security review in `docs/security.md` | **PARTIAL** — existing app ships an unrestricted CORS default and no auth on legacy REST endpoints; documented, not silently changed |

### Slide 7 — Aims & Objectives
| Objective as stated | Implementation | Test evidence | Status |
|---|---|---|---|
| Real-time accident monitoring | `accident_detection/services/sensor_service.dart` (continuous sensor stream) | static | **MET** (impl.) |
| Detect using gyroscope and motion-based techniques | `orientation_analyzer.dart` (gyroscope), `motion_analyzer.dart` (accel) | static | **MET** (impl.) |
| Identify sudden orientation changes indicating a crash | `orientation_analyzer.dart` | static | **MET** (impl.) |
| User confirmation mechanism before sending alerts | `countdown_manager.dart` + `ui/screens/accident_detected_screen.dart` | static | **MET** (impl.) |
| User response within a fixed interval of **15–30 seconds** | `CountdownManager` default is **10 s** (slide 4/8 also say 10 s) | — | **PARTIAL** — deviation D3 |
| Send SOS if no response | `emergency_service.dart` → SMS + Firestore + Socket.IO | static | **MET** (impl.) |
| Accurate location tracking using GPS | `geolocator` usage in `emergency_handling/location_service.dart` | static | **MET** (impl.) |
| Broadcast alerts to nearby registered volunteers | geohash radius search + `helper_accepted` | static | **MET** (impl.) |
| Web-based dashboard for police monitoring | `frontend_dashboard/` | `npm run build` compiled | **MET** |
| Improve response time during the Golden Hour | architectural goal | — | **TARGET** (no measurement in repo) |

### Slide 8 — Methodology / System Architecture
| Requirement as stated | Implementation | Status |
|---|---|---|
| Sensors continuously monitor movement; analysed in real time | `accident_detection/` | **MET** (impl.) |
| Multiple conditions verified before confirming an accident | three analyzers + `detection_engine.dart` gating | **MET** (impl.) |
| 10-second cancellation countdown displayed | `countdown_manager.dart` + `accident_detected_screen.dart` | **MET** |
| If not cancelled: emergency SMS | `sms_service.dart` | **MET** (impl.) |
| …live GPS location shared | `live_tracking_service.dart` | **MET** (impl.) |
| …nearby volunteers notified | `helper_network/notification_service.dart` | **MET** (impl.) |
| …police dashboard updated | backend `socketio.emit('incident_created')` → dashboard `subscribeToIncidentCreated` | **MET** (impl.) |
| Live location streamed until resolved | `@socketio.on('stop_tracking')` in `backend/app.py` + dashboard map | **MET** (impl.) |
| Results displayed on a real-time monitoring dashboard | `frontend_dashboard/src/App.js`, `LiveAlerts`, `IncidentDetail` | **MET** |

### Slide 9 — (architecture diagram only)
The slide contains **no text** — it is a single picture (`slide9_architecture.png`, 485,659 bytes, extracted to `slides_extracted/slide9_architecture.png`).
**Status: BLOCKED.** The diagram content could not be read with the tools available here (this agent cannot interpret images), so no architecture claim from this slide is asserted either way. **Action for the team:** re-export the slide with alt-text, or paste the boxes/arrows as text, before this document can claim 100 % coverage.

### Slide 10 — Technology Stack
| Stated technology | Reality in repo | Status |
|---|---|---|
| Socket.IO (real-time) | `socket_io_client` (Dart) + `flask-socketio` (Python) + `socket.io-client` (React) | **MET** |
| Flask (Python) backend | `backend/app.py` + blueprints (`routes/`) | **MET** |
| Geohash-based geo-fencing for volunteers | `geohash_service.dart`, `radius_search_engine.dart`, backend helper routes | **MET** |
| Police Dashboard: "Frontend React (**Vite**)" | React **18** app built with **react-scripts (Create React App)** — no Vite config or dependency exists | **PARTIAL** — deviation **D1** |
| Mapping: OpenStreetMap / Google Maps API | dashboard: `react-leaflet` + `@react-google-maps/api`; app: `services/map_navigation_service.dart` (Google/Apple/web maps) | **MET** |
| Location Services: Android Location APIs | `geolocator` (Android/iOS location) | **MET** |
| Messaging: Android SMS Manager APIs | `sms_service.dart` uses the `sms:` URI via `url_launcher` — the platform SMS app sends the message; the app does **not** call `SmsManager` directly | **PARTIAL** — deviation **D4** |
| **AI Severity Pipeline: Ultralytics YOLO (pipeline-ready)** | No YOLO / Ultralytics / vision code exists anywhere in the repo | **NOT IMPLEMENTED** — deviation **D2** |

### Slide 11 — Targeted Performance Metrics & Expected Outcomes
> ">96.21% Accident Detection Precision", "<3.51% False Alarm Rate (10s Grace)", "<4.0s Emergency SMS Latency", "<500ms WebSockets Telemetry Delay", "35 min → 10–12 min", "2–3 minutes", "full real-time visibility".

These are explicitly labelled **"Expected"**. No benchmark, dataset, log or test in this repo measures any of them.
**Status: TARGET / NOT MEASURED.** They are *not* reported here as achieved results. Measuring them requires a labelled crash dataset (or instrumented field trials) and a latency harness — out of scope for this integration.

### Slide 12 — Key References
Citations only. No requirements.

---

## 2. Deviations (presentation vs. repository)

| ID | Slide claim | Repository reality | Handling |
|---|---|---|---|
| **D1** | Police dashboard is "React (Vite)" | It is React 18 built with **Create React App** (`react-scripts 5.0.1`); no `vite.config.*`, no `vite` dependency | Kept CRA. Migrating to Vite is a build-tooling change unrelated to this integration; documented, not smuggled in. `npm run build` and `npm run lint` work as-is. |
| **D2** | "AI Severity Pipeline: Ultralytics YOLO (pipeline-ready)" | **No** vision/YOLO code exists. The presentation lists it as *pipeline-ready*, i.e. not delivered | Recorded as **NOT IMPLEMENTED**. The work delivered here adds a *different, additional* capability — a Random Forest **severity predictor** trained on historical structured crash data — and keeps it strictly separate from crash detection. It does **not** claim to implement the YOLO item. See `docs/ml-model.md`. |
| **D3** | Response interval "15 to 30 seconds" (slide 7) vs "10s Grace Window" (slides 4, 8) | Code default is **10 s** (`CountdownManager(durationSeconds: 10)`), and it is configurable | Reported as PARTIAL. The slides contradict each other; the code follows the 10 s variant. Changing it is a product decision, not a bug fix. |
| **D4** | "Android SMS Manager APIs" | `sms_service.dart` opens the `sms:` URI through `url_launcher` (the OS SMS app composes/sends) | Reported as PARTIAL. Direct `SmsManager`/platform-channel sending would need `SEND_SMS` permission and new native code; not added. |
| **D5** | Not mentioned anywhere in the slides | The repo additionally contains a Firebase/Firestore layer (`firestore_service.dart`, `services/firestore_service.py`, `firestore.rules`) and a Medical ID module | Pre-existing features, documented but **not** presented as slide requirements. |

## 3. Capabilities present in the repo but absent from the presentation
Recorded so the trace is complete and nothing is retro-claimed:
- Firestore persistence layer + `firestore.rules` security rules.
- Emergency **Medical ID** (blood group, allergies, QR unlock) — `ui/screens/medical_id_screen.dart`.
- Volunteer-facing app screens (`volunteer_screen.dart`, `volunteer_alert_screen.dart`, `helper/helper_response_screen.dart`).
- Simulated lock screen with QR bypass.
- **New in this integration (not in the slides at all):** the advisory Random Forest severity-prediction module (backend `ml/`, `routes/prediction_routes.py`), dashboard `SeverityPredictionPanel`, Flutter `SeverityPredictionScreen`, and the accompanying test suite. See `docs/ml-model.md` and `docs/api.md`.

## 4. Verification limits of this document
- Slides 1–12 text: extracted and read directly — reliable.
- Slide 9 diagram: **BLOCKED** (image, no text).
- Flutter behaviour ("MET (impl.)" rows where no test is cited): verified by reading the Dart source. `flutter analyze` / `flutter test` were **BLOCKED** in the original environment (no Flutter SDK present); see `docs/testing.md` for the final status, including the attempt to install the SDK.
- Backend, dashboard and ML behaviour: verified by **executed** commands (`pytest`, `npm run build`, `npm run lint`, live `curl` against a running server) — evidence listed in `docs/testing.md`.
