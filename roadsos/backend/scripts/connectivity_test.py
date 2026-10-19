import json, time, urllib.request, urllib.error

BASE = "http://127.0.0.1:5000"
results = []

def http(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode() or "{}")
        except Exception:
            return e.code, {}
    except Exception as e:
        return None, {"error": str(e)}

def check(name, cond, detail=""):
    results.append((name, bool(cond), detail))

# ---- HTTP matrix ----
st, h = http("GET", "/health")
check("GET /health 200", st == 200 and h.get("status") == "OK", f"status={st}")

st, mh = http("GET", "/api/v1/model/health")
m = mh.get("model", {})
check("model available + sha256 verified", st == 200 and m.get("available") is True and m.get("sha256Verified") is True,
      f"available={m.get('available')} sha={m.get('sha256Verified')} nfeat={m.get('nFeaturesIn')}")

st, sc = http("GET", "/api/v1/predictions/schema")
check("schema 5 numeric + 9 categorical", st == 200 and sc.get("success") and len(sc.get("input", {}).get("numericFeatures", [])) == 5 and len(sc.get("input", {}).get("categoricalFeatures", {})) == 9,
      f"numeric={len(sc.get('input',{}).get('numericFeatures',[]))} cat={len(sc.get('input',{}).get('categoricalFeatures',{}))}")

day = {"Year": 2021, "Latitude": 13.0827, "Longitude": 80.2707, "Speed_limit": 30, "Hour": 15,
       "Day_of_Week": "Monday", "Month": "Jan", "Junction_Control": "Give way or uncontrolled",
       "Light_Conditions": "Daylight", "Road_Surface_Conditions": "Dry", "Road_Type": "Single carriageway",
       "Urban_or_Rural_Area": "Urban", "Weather_Conditions": "Fine no high winds", "Vehicle_Type": "Car"}
st, p1 = http("POST", "/api/v1/predictions/severity", {"features": day})
pred1 = p1.get("prediction", {})
check("predict day scenario 200", st == 200 and p1.get("success") and pred1.get("severity") in ("Slight", "Serious", "Fatal"),
      f"severity={pred1.get('severity')} latency={pred1.get('latencyMs')}ms probs={pred1.get('probabilities')}")

# Valid altered scenario: night, wet road, high speed, rural, motorcycle.
night = {"Year": 2019, "Latitude": 51.5, "Longitude": -0.12, "Speed_limit": 60, "Hour": 23,
         "Day_of_Week": "Saturday", "Month": "Dec", "Junction_Control": "Not at junction or within 20 metres",
         "Light_Conditions": "Darkness - no lighting", "Road_Surface_Conditions": "Wet or damp",
         "Road_Type": "Single carriageway", "Urban_or_Rural_Area": "Rural",
         "Weather_Conditions": "Raining no high winds", "Vehicle_Type": "Motorcycle over 500cc"}
st, p2 = http("POST", "/api/v1/predictions/severity", {"features": night})
pred2 = p2.get("prediction", {})
check("predict night+wet+rural scenario 200", st == 200 and p2.get("success") and pred2.get("severity") in ("Slight", "Serious", "Fatal"),
      f"severity={pred2.get('severity')} latency={pred2.get('latencyMs')}ms probs={pred2.get('probabilities')}")
check("probabilities shift (model is live, not canned)",
      pred1.get("probabilities") and pred2.get("probabilities") and pred1.get("probabilities") != pred2.get("probabilities"),
      f"day={pred1.get('probabilities')} vs night={pred2.get('probabilities')}")

st, bad = http("POST", "/api/v1/predictions/severity", {"features": {"Hour": 99}})
check("invalid feature -> 400 INVALID_FEATURES", st == 400 and bad.get("code") == "INVALID_FEATURES",
      f"status={st} code={bad.get('code')}")

st, inc = http("GET", "/incidents")
check("GET /incidents 200", st == 200 and inc.get("success") is True, f"status={st} success={inc.get('success')}")

st, dm = http("POST", "/demo/simulate", {})
check("POST /demo/simulate 200/201", st in (200, 201) and dm.get("success") is True, f"status={st} incidentId={dm.get('incidentId')}")

st, an = http("GET", "/analytics")
check("GET /analytics 200", st == 200, f"status={st}")

# ---- Socket.IO end-to-end (the exact Flutter SOS path) ----
try:
    import socketio
    sio = socketio.Client(reconnection=False)
    got = {"created": []}

    @sio.on("incident_created")
    def on_created(data):
        got["created"].append(data)

    t0 = time.time()
    sio.connect(BASE, transports=["polling", "websocket"], wait_timeout=10)
    check("socket connect", sio.connected, f"connected={sio.connected} in {time.time()-t0:.2f}s")

    sio.emit("create_incident", {
        "latitude": 13.0827, "longitude": 80.2707, "confidence": 0.91,
        "severity": "CRITICAL", "severityScore": 0.84, "plusCode": "7J4VXQCG+Q4",
    })
    deadline = time.time() + 6
    while time.time() < deadline and not got["created"]:
        time.sleep(0.2)
    check("create_incident -> incident_created echoed",
          len(got["created"]) > 0,
          f"received={len(got['created'])} id={got['created'][0].get('id') if got['created'] else None}")

    ack = {}
    def _ack(r):
        ack.update(r if isinstance(r, dict) else {"resp": r})
    sio.emit("helper_respond", {"incidentId": "nope", "helperUid": "h1", "accepted": False, "distanceMeters": 10.0}, callback=_ack)
    time.sleep(1.0)
    check("helper_respond ack received", bool(ack), f"ack={json.dumps(ack)[:120]}")

    sio.disconnect()
except Exception as e:
    check("socket suite ran", False, f"exception: {e}")

# ---- Report ----
print("\n========== CONNECTIVITY TEST REPORT ==========")
passed = sum(1 for _, ok, _ in results if ok)
for name, ok, detail in results:
    print(f"[{'PASS' if ok else 'FAIL'}] {name:52s} {detail}")
print(f"----------------------------------------------\n{passed}/{len(results)} checks passed")
