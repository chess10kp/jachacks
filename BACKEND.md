# Hijac Backend Guide (InsForge + Backboard.io)

This document is the backend integration source of truth for Hijac.

It explains:
- what data lives in InsForge vs Backboard.io,
- how the on-device agent should read and write each backend,
- concrete table/API contracts,
- and the demo-ready resources already provisioned.

Note: your prompt said "backbone.io"; this project uses **Backboard.io** as the memory backend.

## 1) System Responsibility Split

Use each backend for a different job:

- **InsForge (structured system of record)**
  - raw sensor telemetry
  - deterministic episodes (set-down, pickup, geofence-exit)
  - action execution logs and outcomes
  - user rules and compact scorecards
  - integration configuration
- **Backboard.io (cross-session memory / personalization)**
  - durable habits and preference memory
  - retrieval for decision context
  - memory-assisted response generation via thread messages (`memory: "Auto"` / `"Readonly"`)

This aligns with the README requirements in Phase 6B/6C.

## 2) Environment and Credentials

Minimum environment variables:

```bash
# InsForge
INSFORGE_BASE_URL=https://ww8eiidv.us-east.insforge.app
INSFORGE_ANON_KEY=<anon_key_for_client_calls>

# Backboard
BACKBOARD_BASE_URL=https://app.backboard.io/api
BACKBOARD_KEY=<backboard_api_key>

# Emergency Contact (Fall Detection)
EMERGENCY_CONTACT=+1-555-911-0000
EMERGENCY_CONTACT_NAME=Emergency Services
```

Important:
- Keep API keys out of source control.
- `BACKBOARD_KEY` currently appears twice in `.env`; most loaders use the **last value**.
- Store integration IDs (not secrets) in `user_integrations.config_json`.

## 3) InsForge Data Model (Current Project)

All required demo tables are created.

### 3.1 Table Overview

| Table | Purpose |
|---|---|
| `sensor_events` | Raw sensor samples + derived metrics/flags |
| `episode_log` | Normalized episodes (`face_down_stationary`, `pickup_transition`, `geofence_exit`, `fall_detected`) |
| `action_log` | Suggested/executed actions and outcomes |
| `user_patterns` | Compact user scorecard (`accept_rate`, `confidence`, `last_seen`) |
| `conversation_notes` | Focus-mode note snippets and extracted entities |
| `user_integrations` | Per-user integration config (Backboard assistant/thread IDs, webhook config, etc.) |
| `user_rules` | User-created automation rules |

### 3.2 Schemas and Constraints

#### `sensor_events`
- Columns: `id`, `user_id`, `sensor_type`, `payload_json`, `derived_json`, `ts`
- Indexes:
  - `sensor_events_pkey(id)`
  - `idx_sensor_events_user_ts(user_id, ts)`

#### `episode_log`
- Columns: `id`, `user_id`, `episode_type`, `start_ts`, `end_ts`, `confidence`, `context_json`
- Indexes:
  - `episode_log_pkey(id)`
  - `idx_episode_log_user_end_ts(user_id, end_ts)`

#### `action_log`
- Columns: `id`, `user_id`, `episode_id`, `action_type`, `action_payload`, `status`, `result_json`, `ts`
- Foreign key: `episode_id -> episode_log(id)`
- Indexes:
  - `action_log_pkey(id)`
  - `idx_action_log_user_ts(user_id, ts)`

#### `user_patterns`
- Columns: `id`, `user_id`, `accept_rate`, `last_seen`, `confidence`
- Unique: `user_id`

#### `conversation_notes`
- Columns: `id`, `user_id`, `episode_id`, `text`, `entities_json`, `ts`
- Foreign key: `episode_id -> episode_log(id)`
- Indexes:
  - `conversation_notes_pkey(id)`
  - `idx_conversation_notes_user_ts(user_id, ts)`

#### `user_integrations`
- Columns: `id`, `user_id`, `integration_type`, `config_json`, `created_at`
- Unique: `(user_id, integration_type)`

#### `user_rules`
- Columns: `id`, `user_id`, `name`, `condition`, `action_type`, `action_params`, `enabled`, `created_at`
- Indexes:
  - `user_rules_pkey(id)`
  - `idx_user_rules_user(user_id)`

### 3.3 RLS Status

RLS is currently **disabled** on these tables (demo-friendly, not production-hardened).

Before production, enable RLS and enforce per-user policies.

## 4) Backboard.io Model and API Surface

Base URL:

```text
https://app.backboard.io/api
```

Auth header:

```http
X-API-Key: <BACKBOARD_KEY>
```

### 4.1 Core Objects

- **Assistant**: memory scope and behavior for one logical agent persona.
- **Thread**: conversation run context.
- **Memories**: durable memory items linked to assistant.

### 4.2 Endpoints You Need

- `POST /assistants`
- `PUT /assistants/{assistant_id}`
- `POST /assistants/{assistant_id}/threads`
- `POST /threads/{thread_id}/messages`
  - `memory: "Auto"` (save + retrieve)
  - `memory: "Readonly"` (retrieve only)
- `POST /assistants/{assistant_id}/memories` (manual write)
- `GET /assistants/{assistant_id}/memories`
- `POST /assistants/{assistant_id}/memories/search`
- `GET /assistants/memories/operations/{operation_id}`

### 4.3 Memory Namespaces (from README)

Use these namespaces in memory content/metadata:

- `ritual_patterns`
- `geofence_patterns`
- `conversation_commitments`
- `safety_events` (fall detection, emergency calls)

## 5) Provisioned Demo Resources (Current)

Backboard resources created for this project:

- `assistant_id`: `67f63b37-0648-4e96-b084-1c4464bd350b`
- `thread_id`: `05761d4e-3dc3-4fd7-8930-7be7ec7f8d41`

InsForge integration mapping stored in `user_integrations`:

- `user_id`: `demo_user`
- `integration_type`: `backboard`
- `config_json` includes:
  - `assistant_id`
  - `thread_id`
  - `base_url`
  - `default_memory_mode` (`Auto`)
  - `namespaces`

## 6) Data Contracts (Recommended Payload Shapes)

### 6.1 `sensor_events`

```json
{
  "user_id": "demo_user",
  "sensor_type": "motion_2hz",
  "payload_json": {
    "accel_x": 0.04,
    "accel_y": -0.02,
    "accel_z": -9.72,
    "gyro_x": 0.01,
    "gyro_y": 0.02,
    "gyro_z": 0.01,
    "orientation_alpha": 0,
    "orientation_beta": -2,
    "orientation_gamma": 1,
    "timestamp": 1710000000000
  },
  "derived_json": {
    "accel_norm": 9.81,
    "gyro_norm": 0.03,
    "is_flat": true,
    "is_face_down": true,
    "focus_mode_active": true
  }
}
```

### 6.2 `episode_log`

```json
{
  "user_id": "demo_user",
  "episode_type": "face_down_stationary",
  "start_ts": "2026-04-04T15:40:00Z",
  "end_ts": "2026-04-04T15:40:09Z",
  "confidence": 0.93,
  "context_json": {
    "sample_window_ids": [101, 102, 103],
    "detector_version": "v1",
    "source": "motion_pipeline"
  }
}
```

### 6.3 `action_log`

```json
{
  "user_id": "demo_user",
  "episode_id": 42,
  "action_type": "create_calendar_event",
  "action_payload": {
    "title": "Follow up with Alex",
    "start": "2026-04-05T10:00:00Z"
  },
  "status": "suggested",
  "result_json": {
    "decision_source": "memory",
    "confidence_score": 0.78
  }
}
```

### 6.4 `conversation_notes`

```json
{
  "user_id": "demo_user",
  "episode_id": 42,
  "text": "Need follow-up with Alex tomorrow at 10",
  "entities_json": {
    "person": "Alex",
    "datetime": "2026-04-05T10:00:00Z",
    "intent": "follow_up"
  }
}
```

### 6.5 `user_rules`

```json
{
  "user_id": "demo_user",
  "name": "Go home from office",
  "condition": {
    "sensor_type": "geolocation",
    "near_location": { "lat": "OFFICE_LAT", "lng": "OFFICE_LNG", "radius_m": 200 },
    "time_after": "17:00",
    "days": ["MON", "TUE", "WED", "THU", "FRI"]
  },
  "action_type": "open_maps",
  "action_params": { "destination": "home" },
  "enabled": true
}
```

### 6.6 `episode_log` (Fall Detection)

```json
{
  "user_id": "demo_user",
  "episode_type": "fall_detected",
  "start_ts": "2026-04-05T14:30:00Z",
  "end_ts": "2026-04-05T14:30:03Z",
  "confidence": 0.95,
  "context_json": {
    "impact_accel": 45.2,
    "post_impact_stillness_sec": 5.0,
    "orientation_change_deg": 85,
    "detector_version": "v1",
    "source": "fall_detection_pipeline"
  }
}
```

**Fall Detection Logic:**
- **Impact spike**: `accel_norm > 25 m/s²` (3G+ sudden impact)
- **Post-impact stillness**: `gyro_norm < 0.1 rad/s` for 3+ seconds after impact
- **Orientation change**: Device orientation changed >60° (person went from upright to horizontal)
- **Confidence threshold**: 0.90+ triggers immediate emergency call

### 6.7 `action_log` (Emergency Call)

```json
{
  "user_id": "demo_user",
  "episode_id": 99,
  "action_type": "call_emergency_contact",
  "action_payload": {
    "contact_number": "+1-555-911-0000",
    "contact_name": "Emergency Services",
    "reason": "fall_detected",
    "location": { "lat": 37.7749, "lng": -122.4194 }
  },
  "status": "executed",
  "result_json": {
    "decision_source": "rule",
    "confidence_score": 0.95,
    "rule_match": true,
    "auto_triggered": true,
    "countdown_skipped": false,
    "execution_success": true
  }
}
```

### 6.8 `user_rules` (Fall Detection Rule)

```json
{
  "user_id": "demo_user",
  "name": "Emergency call on fall detection",
  "condition": {
    "episode_type": "fall_detected",
    "confidence_min": 0.90
  },
  "action_type": "call_emergency_contact",
  "action_params": {
    "contact_number": "${EMERGENCY_CONTACT}",
    "contact_name": "${EMERGENCY_CONTACT_NAME}",
    "countdown_sec": 30,
    "include_location": true
  },
  "enabled": true
}
```

## 7) Agent Loop Contract (What to Read/Write and When)

Implement one deterministic `runCycle` for each detected episode.

1. **Collect context**
   - current episode from detector
   - latest telemetry window from `sensor_events`
   - active rules from `user_rules`
2. **Read memory**
   - Backboard semantic read for `user_id` + namespace query
   - optional thread message with `memory: "Readonly"` for richer recall
3. **Compute confidence**
   - combine rule match + memory signal + recent outcomes
4. **Decide**
   - if `confidence >= threshold` and `auto_mode` -> execute
   - else suggest action
5. **Persist to InsForge**
   - append `action_log`
   - update `user_patterns` (accept rate/confidence)
6. **Persist to Backboard**
   - write compact memory summary with namespace and outcome

### 7.1 Fall Detection Loop (Special Case)

Fall detection is a **safety-critical flow** with different rules:

1. **Detect fall signature**
   - Impact spike: `accel_norm > 25 m/s²` (3G+)
   - Post-impact stillness: `gyro_norm < 0.1` for 3+ seconds
   - Orientation change: >60° from upright
2. **Compute confidence** (all three signals)
   - Impact only: 0.4
   - Impact + stillness: 0.7
   - Impact + stillness + orientation: 0.95
3. **Trigger countdown** (if confidence >= 0.90)
   - Show 30-second countdown UI
   - User can cancel if false positive
   - If not cancelled, execute emergency call
4. **Execute emergency call**
   - Read `EMERGENCY_CONTACT` from env
   - Log to `action_log` with `auto_triggered: true`
   - Include GPS location in payload
5. **Post-call logging**
   - Write to Backboard: `[safety_events] fall detected, emergency call placed`
   - Update `user_patterns` with event timestamp

## 8) Integration Snippets

### 8.1 Backboard wrappers (HTTP)

```ts
const BACKBOARD_BASE_URL = "https://app.backboard.io/api";

async function backboardWrite(
  assistantId: string,
  userId: string,
  namespace: "ritual_patterns" | "geofence_patterns" | "conversation_commitments",
  observation: string,
  apiKey: string,
) {
  const res = await fetch(`${BACKBOARD_BASE_URL}/assistants/${assistantId}/memories`, {
    method: "POST",
    headers: {
      "X-API-Key": apiKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      content: `[${namespace}] user:${userId} ${observation}`,
      metadata: { namespace, user_id: userId },
    }),
  });
  if (!res.ok) throw new Error(`Backboard write failed: ${res.status}`);
  return res.json();
}

async function backboardRead(assistantId: string, userId: string, query: string, apiKey: string) {
  const res = await fetch(`${BACKBOARD_BASE_URL}/assistants/${assistantId}/memories/search`, {
    method: "POST",
    headers: {
      "X-API-Key": apiKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ query: `user:${userId} ${query}`, limit: 5 }),
  });
  if (!res.ok) throw new Error(`Backboard read failed: ${res.status}`);
  return res.json();
}
```

### 8.2 Backboard memory-assisted turn

```ts
async function backboardMessageWithMemory(
  threadId: string,
  content: string,
  mode: "Auto" | "Readonly",
  apiKey: string,
) {
  const res = await fetch(`https://app.backboard.io/api/threads/${threadId}/messages`, {
    method: "POST",
    headers: {
      "X-API-Key": apiKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ content, stream: false, memory: mode }),
  });
  if (!res.ok) throw new Error(`Backboard message failed: ${res.status}`);
  return res.json();
}
```

### 8.3 InsForge writes (SDK-style contract)

InsForge SDK note: inserts use arrays and operations return `{ data, error }`.

```ts
// Pseudocode shape (match your SDK version)
const { data, error } = await insforge.from("sensor_events").insert([
  {
    user_id: "demo_user",
    sensor_type: "motion_2hz",
    payload_json: payload,
    derived_json: derived,
  },
]);
if (error) throw error;
```

## 9) Interfacing Rules for Each Flow

### 9.1 Sensor ingestion
- Write each sample window to `sensor_events`.
- Keep high-volume raw values in `payload_json`; keep computed booleans/norms in `derived_json`.

### 9.2 Episode detection
- On detector completion, write one row to `episode_log`.
- Include `confidence` and compact detector context.

### 9.3 Action decision + execution
- Read `user_rules` + Backboard memory + recent `action_log`.
- Write suggestion/execution status in `action_log`.
- Update `user_patterns`.

### 9.4 Focus notes
- Store raw note in `conversation_notes.text`.
- Store extracted entities in `conversation_notes.entities_json`.
- Write commitment summary to Backboard namespace `conversation_commitments`.

## 10) Operational Checklist (Demo)

- [ ] `user_integrations` has a `backboard` config for demo user.
- [ ] Backboard `assistant_id` and active `thread_id` are valid.
- [ ] Motion pipeline writes `sensor_events` at 2 Hz effective cadence.
- [ ] Episode detector writes `face_down_stationary` and `pickup_transition` rows.
- [ ] Decision loop writes `action_log` for both suggested and executed actions.
- [ ] UI exposes `confidence_score`, memory reasons, and decision source (`rule`/`memory`/`both`).
- [ ] Backboard fallback exists (if API fails, continue with InsForge-only flow and local cache).

## 11) Quick Verification Queries

```sql
-- Recent sensor events
SELECT user_id, sensor_type, ts
FROM sensor_events
ORDER BY ts DESC
LIMIT 20;

-- Recent episodes
SELECT user_id, episode_type, confidence, end_ts
FROM episode_log
ORDER BY end_ts DESC
LIMIT 20;

-- Recent actions
SELECT user_id, action_type, status, ts
FROM action_log
ORDER BY ts DESC
LIMIT 20;

-- Backboard integration config
SELECT user_id, integration_type, config_json
FROM user_integrations
WHERE integration_type = 'backboard';
```

---

If you update schemas, memory namespaces, or decision states, update this file in the same PR so backend behavior stays explicit and demo-safe.
