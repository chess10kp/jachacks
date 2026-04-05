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
INSFORGE_BASE_URL=https://your-project.region.insforge.app
INSFORGE_ANON_KEY=<anon_key_for_client_calls>

# Backboard
BACKBOARD_BASE_URL=https://app.backboard.io/api
BACKBOARD_KEY=<backboard_api_key>
BACKBOARD_ASSISTANT_ID=<backboard_assistant_id>
BACKBOARD_THREAD_ID=<backboard_thread_id>

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
| `episode_log` | Normalized episodes (`face_down_stationary`, `pickup_transition`, `geofence_exit`, `fall_detected`, `safety_concern`) |
| `action_log` | Suggested/executed actions and outcomes |
| `user_patterns` | Compact user scorecard (`accept_rate`, `confidence`, `last_seen`) |
| `conversation_notes` | Focus-mode note snippets and extracted entities |
| `user_integrations` | Per-user integration config (Backboard assistant/thread IDs, webhook config, etc.) |
| `user_rules` | User-created automation rules |
| `location_history` | Historical GPS data for baseline patterns and safe zones (safety assessment) |
| `safety_assessments` | Backboard safety evaluation logs with passcode challenge tracking |

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

#### `location_history`
- Columns: `id` (UUID), `user_id`, `latitude`, `longitude`, `accuracy_meters`, `altitude_meters`, `speed_mps`, `heading_degrees`, `location_type`, `is_safe_zone`, `visit_count`, `first_seen_at`, `last_seen_at`, `created_at`
- Indexes:
  - `idx_location_history_user(user_id)`
  - `idx_location_history_coords(latitude, longitude)`
  - `idx_location_history_safe_zone(user_id, is_safe_zone)` WHERE `is_safe_zone = true`
  - `idx_location_history_last_seen(user_id, last_seen_at DESC)`

#### `safety_assessments`
- Columns: `id` (UUID), `user_id`, `trigger_type`, `episode_id`, `current_lat`, `current_lng`, `distance_from_centroid_meters`, `nearest_safe_zone_meters`, `location_deviation_score`, `gyro_variance_x`, `gyro_variance_y`, `gyro_variance_z`, `struggle_duration_ms`, `struggle_intensity_score`, `backboard_thread_id`, `backboard_response`, `safety_concern_level`, `recommended_action`, `requires_passcode_challenge`, `passcode_prompted_at`, `passcode_verified`, `passcode_timeout_at`, `final_action_taken`, `false_positive`, `user_feedback`, `created_at`, `resolved_at`
- Indexes:
  - `idx_safety_assessments_user(user_id)`
  - `idx_safety_assessments_trigger(trigger_type)`
  - `idx_safety_assessments_concern(user_id, safety_concern_level)`
  - `idx_safety_assessments_unresolved(user_id, resolved_at)` WHERE `resolved_at IS NULL`

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

- `assistant_id`: `<your-backboard-assistant-id>` (UUID)
- `thread_id`: `<your-backboard-thread-id>` (UUID)

InsForge integration mapping stored in `user_integrations`:

- `user_id`: `demo_user`
- `integration_type`: `backboard`
- `config_json` includes:
  - `assistant_id`
  - `thread_id`
  - `base_url`
  - `default_memory_mode` (`Auto`)
  - `namespaces`

### 5.1 Seeded User Rules

| ID | Name | Action Type | Trigger |
|---|---|---|---|
| 1 | Go home from office | `open_maps` | Geofence exit after 5pm weekdays |
| 2 | Gym arrived notification | `send_notification` | Near gym location |
| 3 | Emergency call on fall detection | `call_emergency_contact` | Fall detected with confidence >= 0.90 |
| 4 | Safety assessment with passcode challenge | `passcode_challenge` | Struggle/location anomaly + medium/high Backboard concern |

### 5.2 Seeded Location History (demo_user)

| Location Type | Coordinates | Safe Zone | Visit Count |
|---|---|---|---|
| home | (37.7749, -122.4194) | Yes | 150 |
| work | (37.7850, -122.4000) | Yes | 80 |
| routine (gym) | (37.7700, -122.4100) | Yes | 35 |

### 5.3 Seeded Backboard Memories

**Safety Assessment Criteria:**
```
[safety_events] ASSESSMENT_CRITERIA: When evaluating safety concerns, consider:
1) Location deviation >2km from centroid = medium concern, >4km = high concern
2) Struggle intensity >0.6 = medium concern, >0.8 = high concern
3) Combined location+struggle = escalate one level
4) Time context: late night (11pm-5am) in unfamiliar location = escalate one level
5) User historical false positives: if user frequently verifies at similar locations, reduce concern level
```

**Action Guidelines:**
```
[safety_events] ACTION_GUIDELINES: Recommended actions by concern level:
- NONE/LOW = none or monitor (increase sensor sampling)
- MEDIUM = passcode_challenge (60s timeout, then escalate)
- HIGH = countdown_alert (30s countdown, user can cancel)
- CRITICAL = immediate_call (no delay)
```

**User Baseline:**
```
[safety_events] user:demo_user BASELINE: User typical locations include home, office, gym.
User typically at home before 8am and after 7pm weekdays.
User exercises at gym Mon/Wed/Fri 6-7am (may trigger struggle detection during workouts - consider as false positive context).
```

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

### 6.9 `user_rules` (Safety Assessment with Passcode Challenge)

```json
{
  "user_id": "demo_user",
  "name": "Safety assessment with passcode challenge",
  "condition": {
    "trigger_types": ["struggle_detected", "location_anomaly"],
    "backboard_concern_levels": ["medium", "high"],
    "delegate_to_backboard": true
  },
  "action_type": "passcode_challenge",
  "action_params": {
    "passcode_timeout_sec": 60,
    "escalation_action": "countdown_alert",
    "countdown_sec": 30,
    "final_action": "call_emergency_contact",
    "include_location": true,
    "notify_emergency_contact_on_timeout": true
  },
  "enabled": true
}
```

### 6.10 `user_patterns`

```json
{
  "user_id": "demo_user",
  "accept_rate": 0.85,
  "last_seen": "2026-04-05T14:30:00Z",
  "confidence": 0.78
}
```

**Field descriptions:**
- `accept_rate`: Ratio of accepted vs suggested actions (0.0 - 1.0)
- `last_seen`: Last activity timestamp (ISO8601)
- `confidence`: Agent's confidence in predicting user preferences (0.0 - 1.0)

### 6.11 `user_integrations`

```json
{
  "user_id": "demo_user",
  "integration_type": "backboard",
  "config_json": {
    "assistant_id": "<your-backboard-assistant-id>",
    "thread_id": "<your-backboard-thread-id>",
    "base_url": "https://app.backboard.io/api",
    "default_memory_mode": "Auto",
    "namespaces": ["ritual_patterns", "geofence_patterns", "conversation_commitments", "safety_events"]
  },
  "created_at": "2026-04-01T00:00:00Z"
}
```

**Supported integration types:**
- `backboard`: Backboard.io memory integration
- `calendar`: Google Calendar (future)
- `webhook`: Generic webhook endpoints (future)

### 6.12 `location_history`

```json
{
  "user_id": "demo_user",
  "latitude": 37.7749,
  "longitude": -122.4194,
  "accuracy_meters": 10.5,
  "altitude_meters": 15.0,
  "speed_mps": 1.2,
  "heading_degrees": 45.0,
  "location_type": "home",
  "is_safe_zone": true,
  "visit_count": 150,
  "first_seen_at": "2026-01-15T08:00:00Z",
  "last_seen_at": "2026-04-05T22:30:00Z"
}
```

**Location types:** `home`, `work`, `routine`, `transit`, `unknown`

### 6.13 `safety_assessments`

```json
{
  "user_id": "demo_user",
  "trigger_type": "struggle_detected",
  "episode_id": "uuid-of-related-episode",
  
  "current_lat": 37.7850,
  "current_lng": -122.4300,
  "distance_from_centroid_meters": 1250.5,
  "nearest_safe_zone_meters": 800.0,
  "location_deviation_score": 0.72,
  
  "gyro_variance_x": 2.5,
  "gyro_variance_y": 3.1,
  "gyro_variance_z": 1.8,
  "struggle_duration_ms": 2500,
  "struggle_intensity_score": 0.65,
  
  "backboard_thread_id": "<your-backboard-thread-id>",
  "backboard_response": "MEDIUM concern. User is 1.2km from usual locations with erratic movement patterns.",
  "safety_concern_level": "medium",
  "recommended_action": "passcode_challenge",
  "requires_passcode_challenge": true,
  
  "passcode_prompted_at": "2026-04-05T14:30:00Z",
  "passcode_verified": false,
  "passcode_timeout_at": "2026-04-05T14:31:00Z",
  
  "final_action_taken": "call_emergency_contact",
  "false_positive": false,
  "user_feedback": null,
  "resolved_at": "2026-04-05T14:32:30Z"
}
```

**Trigger types:** `fall_detected`, `location_anomaly`, `struggle_detected`, `manual_check`
**Concern levels:** `none`, `low`, `medium`, `high`, `critical`
**Recommended actions:** `none`, `monitor`, `passcode_challenge`, `countdown_alert`, `immediate_call`

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

### 7.2 Safety Assessment Loop (Backboard-Delegated Decision Making)

Safety assessment uses **Backboard as the decision-maker** for nuanced safety scenarios that go beyond simple fall detection. The agent collects context and delegates the safety judgment to Backboard's LLM.

#### New Tables

**`location_history`** - Historical GPS data for baseline patterns:
```json
{
  "user_id": "demo_user",
  "latitude": 37.7749,
  "longitude": -122.4194,
  "accuracy_meters": 10.5,
  "altitude_meters": 15.0,
  "speed_mps": 1.2,
  "heading_degrees": 45.0,
  "location_type": "routine",
  "is_safe_zone": true,
  "visit_count": 25,
  "first_seen_at": "2026-03-01T08:00:00Z",
  "last_seen_at": "2026-04-05T08:15:00Z"
}
```

Location types: `routine`, `work`, `home`, `transit`, `unknown`

**`safety_assessments`** - Backboard evaluation logs:
```json
{
  "user_id": "demo_user",
  "trigger_type": "struggle_detected",
  "episode_id": "uuid-of-related-episode",
  
  "current_lat": 37.7850,
  "current_lng": -122.4300,
  "distance_from_centroid_meters": 1250.5,
  "nearest_safe_zone_meters": 800.0,
  "location_deviation_score": 0.72,
  
  "gyro_variance_x": 2.5,
  "gyro_variance_y": 3.1,
  "gyro_variance_z": 1.8,
  "struggle_duration_ms": 2500,
  "struggle_intensity_score": 0.65,
  
  "backboard_thread_id": "<your-backboard-thread-id>",
  "backboard_response": "MEDIUM concern. User is 1.2km from usual locations with erratic movement patterns. Recommend passcode verification.",
  "safety_concern_level": "medium",
  "recommended_action": "passcode_challenge",
  "requires_passcode_challenge": true,
  
  "passcode_prompted_at": "2026-04-05T14:30:00Z",
  "passcode_verified": null,
  "passcode_timeout_at": "2026-04-05T14:31:00Z",
  
  "final_action_taken": null,
  "false_positive": null,
  "user_feedback": null
}
```

Trigger types: `fall_detected`, `location_anomaly`, `struggle_detected`, `manual_check`
Safety concern levels: `none`, `low`, `medium`, `high`, `critical`

#### Struggle Detection Criteria

"Struggle" refers to erratic gyroscope patterns that may precede a fall or indicate distress:

1. **Gyroscope variance threshold**: Any axis variance > 1.5 rad/s² over 1-3 second window
2. **Multi-axis instability**: Variance on 2+ axes simultaneously
3. **Duration**: Pattern persists for 500ms - 5000ms
4. **Not walking**: Excludes regular periodic walking patterns (sinusoidal)

Struggle intensity score calculation:
```
intensity = min(1.0, (gyro_variance_total / 6.0) * (duration_ms / 3000))
```

Where `gyro_variance_total = sqrt(var_x² + var_y² + var_z²)`

#### Location Deviation Calculation

1. **Compute user's location centroid** from `location_history`:
   ```sql
   SELECT AVG(latitude) as centroid_lat, AVG(longitude) as centroid_lng
   FROM location_history
   WHERE user_id = $1 AND last_seen_at > NOW() - INTERVAL '30 days'
   ```

2. **Calculate distance from centroid** using Haversine formula

3. **Find nearest safe zone**:
   ```sql
   SELECT MIN(distance_meters) as nearest_safe
   FROM (
     SELECT haversine(current_lat, current_lng, latitude, longitude) as distance_meters
     FROM location_history
     WHERE user_id = $1 AND is_safe_zone = true
   ) sub
   ```

4. **Deviation score**:
   ```
   deviation_score = min(1.0, distance_from_centroid / 5000)  -- 5km = max concern
   ```

#### Backboard Safety Assessment Prompt

Send to Backboard thread with `memory: "Auto"`:

```
[SAFETY_ASSESSMENT_REQUEST]
User: {user_id}
Timestamp: {iso_timestamp}
Trigger: {trigger_type}

LOCATION CONTEXT:
- Current position: ({lat}, {lng})
- Distance from historical centroid: {distance_from_centroid_meters}m
- Nearest safe zone: {nearest_safe_zone_meters}m
- Location deviation score: {location_deviation_score}

MOTION CONTEXT:
- Struggle detected: {yes/no}
- Struggle intensity: {struggle_intensity_score}
- Struggle duration: {struggle_duration_ms}ms
- Gyro variance (x,y,z): ({var_x}, {var_y}, {var_z})

HISTORICAL CONTEXT:
- Time of day: {time}
- Day of week: {day}
- User's typical location at this time: {typical_location_type}

Based on this context and the user's historical patterns in your memory, assess the safety concern level and recommend an action.

Respond in this format:
CONCERN_LEVEL: none|low|medium|high|critical
RECOMMENDED_ACTION: none|monitor|passcode_challenge|countdown_alert|immediate_call
REASONING: <brief explanation>
```

#### Safety Assessment Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    SAFETY ASSESSMENT FLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. TRIGGER DETECTED                                             │
│     ├── fall_detected (from 7.1)                                │
│     ├── struggle_detected (gyro variance)                       │
│     ├── location_anomaly (far from centroid)                    │
│     └── manual_check (user-initiated)                           │
│                         │                                        │
│                         ▼                                        │
│  2. COLLECT CONTEXT                                              │
│     ├── Current GPS position                                    │
│     ├── Location history (centroid, safe zones)                 │
│     ├── Recent gyroscope data (variance, patterns)              │
│     └── Time/day context                                        │
│                         │                                        │
│                         ▼                                        │
│  3. DELEGATE TO BACKBOARD                                        │
│     ├── Send assessment prompt with all context                 │
│     ├── memory: "Auto" (retrieves + saves)                      │
│     └── Parse response for concern_level + action               │
│                         │                                        │
│                         ▼                                        │
│  4. PERSIST ASSESSMENT                                           │
│     └── Write to safety_assessments table                       │
│                         │                                        │
│                         ▼                                        │
│  5. EXECUTE RECOMMENDED ACTION                                   │
│     ├── none: No action, log only                               │
│     ├── monitor: Increase sensor sampling rate                  │
│     ├── passcode_challenge: Prompt user for passcode            │
│     │   ├── VERIFIED: Mark false_positive, log                  │
│     │   └── TIMEOUT (60s): Escalate to countdown_alert          │
│     ├── countdown_alert: 30-second countdown                    │
│     │   ├── CANCELLED: Mark false_positive, log                 │
│     │   └── TIMEOUT: Execute immediate_call                     │
│     └── immediate_call: Call emergency contact NOW              │
│                         │                                        │
│                         ▼                                        │
│  6. POST-ACTION LOGGING                                          │
│     ├── Update safety_assessments.final_action_taken            │
│     ├── Write to Backboard: [safety_events] outcome             │
│     └── Update user_patterns with event                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Passcode Challenge Flow

When Backboard recommends `passcode_challenge`:

1. **Prompt UI**: Show "Safety Check - Enter your passcode to confirm you're OK"
2. **Set timeout**: 60 seconds
3. **On correct passcode**:
   - Update `safety_assessments`: `passcode_verified = true`, `false_positive = true`
   - Write to Backboard: `[safety_events] passcode verified, false positive at {location}`
4. **On timeout or 3 failed attempts**:
   - Update `safety_assessments`: `passcode_verified = false`
   - Escalate to `countdown_alert` (30-second emergency countdown)
5. **During countdown**:
   - User can still cancel with passcode
   - If no cancellation, execute emergency call

#### Backboard Memory Namespace: `safety_events`

Examples of memories to persist:

```
[safety_events] user:demo_user 2026-04-05T14:30:00Z struggle detected at unfamiliar location (1.2km from centroid), passcode verified - false positive
[safety_events] user:demo_user 2026-04-05T16:45:00Z fall detected at home, emergency call placed, user confirmed fall via callback
[safety_events] user:demo_user 2026-04-06T09:00:00Z location anomaly at new workplace - user marked as safe zone
```

These memories help Backboard make better decisions over time by learning:
- Which locations are actually safe (even if unfamiliar)
- False positive patterns (e.g., user often triggers struggle detection while exercising)
- Time-of-day patterns (e.g., user is often at gym at 6am, far from home)

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
