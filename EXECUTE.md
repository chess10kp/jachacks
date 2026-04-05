# Hijac Demo Execution Commands

This document provides curl/HTTP commands that can be invoked from Jac code via `shell{}` or adapted for the `hj {}` HTTP client codespace. Use these to trigger demo scenarios without modifying the Jac codebase directly.

## Credentials

```bash
# InsForge
export INSFORGE_BASE_URL="https://your-project.region.insforge.app"
export INSFORGE_ANON_KEY="<your-insforge-anon-key>"

# Backboard
export BACKBOARD_BASE_URL="https://app.backboard.io/api"
export BACKBOARD_API_KEY="<your-backboard-api-key>"
export BACKBOARD_ASSISTANT_ID="<your-backboard-assistant-id>"
export BACKBOARD_THREAD_ID="<your-backboard-thread-id>"

# Emergency Contact (for fall/safety detection)
export EMERGENCY_CONTACT="+1-555-911-0000"
export EMERGENCY_CONTACT_NAME="Emergency Services"
```

> **Note**: Get actual credentials from `.env` file (not committed to git).

---

## Type Definitions

### InsForge Types

```typescript
// Sensor Event
interface SensorEvent {
  user_id: string;           // "demo_user"
  sensor_type: string;       // "motion_2hz" | "geolocation" | "barometer"
  payload_json: {
    accel_x: number;         // m/s²
    accel_y: number;
    accel_z: number;         // ~-9.8 when face-down
    gyro_x: number;          // rad/s
    gyro_y: number;
    gyro_z: number;
    timestamp?: number;      // epoch ms
  };
  derived_json: {
    accel_norm: number;      // sqrt(x²+y²+z²)
    gyro_norm: number;       // sqrt(x²+y²+z²)
    is_flat: boolean;        // accel_norm ≈ 9.8
    is_face_down: boolean;   // accel_z < -7.5
    focus_mode_active: boolean;
  };
  ts?: string;               // ISO8601, auto-generated if omitted
}

// Episode
interface Episode {
  user_id: string;
  episode_type: "face_down_stationary" | "pickup_transition" | "geofence_exit" | "fall_detected";
  start_ts: string;          // ISO8601
  end_ts: string;            // ISO8601
  confidence: number;        // 0.0 - 1.0
  context_json: {
    duration_sec?: number;
    avg_gyro_norm?: number;
    accel_spike?: number;
    prior_episode?: string;
    // Fall detection specific
    impact_accel?: number;   // m/s² at impact
    post_impact_stillness_sec?: number;
    orientation_change_deg?: number;
    detector_version: string;
    source: string;
  };
}

// Action
interface Action {
  user_id: string;
  episode_id: number;        // FK to episode_log.id
  action_type: "create_calendar_event" | "send_notification" | "open_maps" | "set_reminder" | "call_emergency_contact";
  action_payload: Record<string, any>;
  status: "suggested" | "accepted" | "rejected" | "executed" | "failed";
  result_json: {
    decision_source: "rule" | "memory" | "both";
    confidence_score: number;
    memory_reason?: string;
    rule_match?: boolean;
    user_response?: string;
    execution_success?: boolean;
    auto_triggered?: boolean;  // For emergency actions
    countdown_skipped?: boolean;
  };
  ts?: string;
}

// User Patterns
interface UserPatterns {
  user_id: string;
  accept_rate: number;       // 0.0 - 1.0
  last_seen: string;         // ISO8601
  confidence: number;        // 0.0 - 1.0
}

// User Rule
interface UserRule {
  user_id: string;
  name: string;
  condition: {
    sensor_type: string;
    near_location?: { lat: number; lng: number; radius_m: number };
    time_after?: string;     // "HH:MM"
    days?: string[];         // ["MON", "TUE", ...]
  };
  action_type: string;
  action_params: Record<string, any>;
  enabled: boolean;
}

// Location History (for safety assessment baseline)
interface LocationHistory {
  user_id: string;
  latitude: number;
  longitude: number;
  accuracy_meters?: number;
  altitude_meters?: number;
  speed_mps?: number;
  heading_degrees?: number;
  location_type: "routine" | "work" | "home" | "transit" | "unknown";
  is_safe_zone: boolean;
  visit_count: number;
  first_seen_at?: string;    // ISO8601
  last_seen_at?: string;     // ISO8601
}

// Safety Assessment (Backboard-delegated decisions)
interface SafetyAssessment {
  user_id: string;
  trigger_type: "fall_detected" | "location_anomaly" | "struggle_detected" | "manual_check";
  episode_id?: string;
  
  // Location metrics
  current_lat?: number;
  current_lng?: number;
  distance_from_centroid_meters?: number;
  nearest_safe_zone_meters?: number;
  location_deviation_score?: number;  // 0.0 - 1.0
  
  // Struggle metrics
  gyro_variance_x?: number;
  gyro_variance_y?: number;
  gyro_variance_z?: number;
  struggle_duration_ms?: number;
  struggle_intensity_score?: number;  // 0.0 - 1.0
  
  // Backboard decision
  backboard_thread_id?: string;
  backboard_response?: string;
  safety_concern_level: "none" | "low" | "medium" | "high" | "critical";
  recommended_action?: "none" | "monitor" | "passcode_challenge" | "countdown_alert" | "immediate_call";
  requires_passcode_challenge: boolean;
  
  // Passcode challenge flow
  passcode_prompted_at?: string;      // ISO8601
  passcode_verified?: boolean;
  passcode_timeout_at?: string;       // ISO8601
  
  // Outcome
  final_action_taken?: string;
  false_positive?: boolean;
  user_feedback?: string;
  resolved_at?: string;               // ISO8601
}
```

### Backboard Types

```typescript
// Memory Write
interface MemoryWrite {
  content: string;           // Include namespace tag: "[ritual_patterns] ..."
  metadata: {
    namespace: "ritual_patterns" | "geofence_patterns" | "conversation_commitments" | "safety_events";
    user_id: string;
    confidence?: string;
  };
}

// Memory Search
interface MemorySearch {
  query: string;             // "user:demo_user focus ritual"
  limit?: number;            // default 5
}

// Thread Message
interface ThreadMessage {
  content: string;           // Query or observation
  stream: boolean;           // false for sync response
  memory: "Auto" | "Readonly"; // Auto = save + retrieve, Readonly = retrieve only
}

// Memory Response
interface MemoryResult {
  id: string;
  content: string;
  score: number;             // similarity score
  created_at: string;
}
```

---

## InsForge REST API Commands

Base pattern:
```bash
curl -X METHOD "${INSFORGE_BASE_URL}/api/database/records/{table}" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d 'JSON_BODY'
```

### 1. Log Sensor Event

```bash
curl -X POST "${INSFORGE_BASE_URL}/api/database/records/sensor_events" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '[{
    "user_id": "demo_user",
    "sensor_type": "motion_2hz",
    "payload_json": {
      "accel_x": 0.02,
      "accel_y": -0.01,
      "accel_z": -9.78,
      "gyro_x": 0.01,
      "gyro_y": 0.00,
      "gyro_z": 0.01
    },
    "derived_json": {
      "accel_norm": 9.78,
      "gyro_norm": 0.014,
      "is_flat": true,
      "is_face_down": true,
      "focus_mode_active": true
    }
  }]'
```

**Expected Response:**
```json
[{
  "id": "6",
  "user_id": "demo_user",
  "sensor_type": "motion_2hz",
  "payload_json": {...},
  "derived_json": {...},
  "ts": "2026-04-05T07:00:00.000Z"
}]
```

### 2. Log Episode (Face Down Stationary)

```bash
curl -X POST "${INSFORGE_BASE_URL}/api/database/records/episode_log" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '[{
    "user_id": "demo_user",
    "episode_type": "face_down_stationary",
    "start_ts": "2026-04-05T10:00:00Z",
    "end_ts": "2026-04-05T10:25:00Z",
    "confidence": 0.94,
    "context_json": {
      "duration_sec": 1500,
      "avg_gyro_norm": 0.015,
      "detector_version": "v1",
      "source": "motion_pipeline"
    }
  }]'
```

### 3. Log Episode (Pickup Transition)

```bash
curl -X POST "${INSFORGE_BASE_URL}/api/database/records/episode_log" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '[{
    "user_id": "demo_user",
    "episode_type": "pickup_transition",
    "start_ts": "2026-04-05T10:25:00Z",
    "end_ts": "2026-04-05T10:25:03Z",
    "confidence": 0.92,
    "context_json": {
      "accel_spike": 8.5,
      "gyro_spike": 1.8,
      "prior_episode": "face_down_stationary",
      "detector_version": "v1",
      "source": "motion_pipeline"
    }
  }]'
```

### 4. Log Action (Suggested)

```bash
curl -X POST "${INSFORGE_BASE_URL}/api/database/records/action_log" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '[{
    "user_id": "demo_user",
    "episode_id": 3,
    "action_type": "create_calendar_event",
    "action_payload": {
      "title": "Follow up with Alex",
      "start": "2026-04-05T11:00:00Z",
      "duration_min": 30
    },
    "status": "suggested",
    "result_json": {
      "decision_source": "memory",
      "confidence_score": 0.82,
      "memory_reason": "user accepts follow-up reminders with person + time",
      "rule_match": false
    }
  }]'
```

### 5. Update Action Status (Accept/Reject)

```bash
# Accept
curl -X PATCH "${INSFORGE_BASE_URL}/api/database/records/action_log?id=eq.4" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{
    "status": "accepted",
    "result_json": {
      "decision_source": "memory",
      "confidence_score": 0.82,
      "user_response": "accepted",
      "latency_ms": 1500
    }
  }'

# Reject
curl -X PATCH "${INSFORGE_BASE_URL}/api/database/records/action_log?id=eq.4" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{
    "status": "rejected",
    "result_json": {
      "decision_source": "memory",
      "confidence_score": 0.82,
      "user_response": "rejected",
      "rejection_reason": "not now"
    }
  }'
```

### 6. Update User Patterns

```bash
curl -X PATCH "${INSFORGE_BASE_URL}/api/database/records/user_patterns?user_id=eq.demo_user" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '{
    "accept_rate": 0.88,
    "confidence": 0.80,
    "last_seen": "2026-04-05T10:25:03Z"
  }'
```

### 7. Query Recent Episodes

```bash
curl -X GET "${INSFORGE_BASE_URL}/api/database/records/episode_log?user_id=eq.demo_user&order=end_ts.desc&limit=5" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}"
```

### 8. Query Active Rules

```bash
curl -X GET "${INSFORGE_BASE_URL}/api/database/records/user_rules?user_id=eq.demo_user&enabled=eq.true" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}"
```

### 9. Query Backboard Config

```bash
curl -X GET "${INSFORGE_BASE_URL}/api/database/records/user_integrations?user_id=eq.demo_user&integration_type=eq.backboard" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}"
```

---

## Backboard.io API Commands

Base pattern:
```bash
curl -X METHOD "${BACKBOARD_BASE_URL}/endpoint" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d 'JSON_BODY'
```

### 1. Write Memory

```bash
curl -X POST "${BACKBOARD_BASE_URL}/assistants/${BACKBOARD_ASSISTANT_ID}/memories" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "[ritual_patterns] user:demo_user completed 25-min focus session, accepted calendar follow-up. Confidence: 0.88",
    "metadata": {
      "namespace": "ritual_patterns",
      "user_id": "demo_user",
      "confidence": "0.88"
    }
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Memory added successfully",
  "memory_id": "uuid-here",
  "content": "[ritual_patterns] user:demo_user completed 25-min focus session..."
}
```

### 2. Search Memory

```bash
curl -X POST "${BACKBOARD_BASE_URL}/assistants/${BACKBOARD_ASSISTANT_ID}/memories/search" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "user:demo_user focus ritual morning",
    "limit": 5
  }'
```

**Expected Response:**
```json
{
  "memories": [
    {
      "id": "uuid",
      "content": "[ritual_patterns] user:demo_user morning focus sessions...",
      "score": 0.85,
      "created_at": "2026-04-05T06:43:02"
    }
  ],
  "total_count": 1
}
```

### 3. List All Memories

```bash
curl -X GET "${BACKBOARD_BASE_URL}/assistants/${BACKBOARD_ASSISTANT_ID}/memories" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}"
```

### 4. Send Thread Message (with Memory Recall)

```bash
# Readonly mode - retrieve memories without saving
curl -X POST "${BACKBOARD_BASE_URL}/threads/${BACKBOARD_THREAD_ID}/messages" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "What do you remember about user:demo_user focus rituals and follow-up preferences?",
    "stream": false,
    "memory": "Readonly"
  }'

# Auto mode - retrieve and save new memories
curl -X POST "${BACKBOARD_BASE_URL}/threads/${BACKBOARD_THREAD_ID}/messages" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "user:demo_user just completed a 25-minute focus session and accepted a calendar follow-up with Alex at 11am",
    "stream": false,
    "memory": "Auto"
  }'
```

**Expected Response:**
```json
{
  "role": "assistant",
  "content": "I recall that demo_user has morning focus sessions lasting 20-30 minutes...",
  "message_id": "uuid",
  "status": "COMPLETED",
  "metadata_": {
    "retrieved_memories": [
      {"id": "uuid", "score": 0.85, "memory": "..."}
    ]
  }
}
```

### 5. Get Assistant Details

```bash
curl -X GET "${BACKBOARD_BASE_URL}/assistants/${BACKBOARD_ASSISTANT_ID}" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}"
```

### 6. Get Thread with Messages

```bash
curl -X GET "${BACKBOARD_BASE_URL}/threads/${BACKBOARD_THREAD_ID}" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}"
```

---

## Demo Scenario Scripts

### Scenario 1: Focus Ritual Complete Flow

This simulates: phone placed face-down → 25 min passes → phone picked up → agent suggests action → user accepts

```bash
#!/bin/bash
# Run from project root

# 1. Log face-down sensor event
curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/sensor_events" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '[{
    "user_id": "demo_user",
    "sensor_type": "motion_2hz",
    "payload_json": {"accel_x": 0.01, "accel_y": 0.00, "accel_z": -9.79, "gyro_x": 0.00, "gyro_y": 0.01, "gyro_z": 0.00},
    "derived_json": {"accel_norm": 9.79, "gyro_norm": 0.01, "is_flat": true, "is_face_down": true, "focus_mode_active": true}
  }]'

# 2. Log face_down_stationary episode
EPISODE_RESPONSE=$(curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/episode_log" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '[{
    "user_id": "demo_user",
    "episode_type": "face_down_stationary",
    "start_ts": "'$(date -u -d '-25 minutes' +%Y-%m-%dT%H:%M:%SZ)'",
    "end_ts": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "confidence": 0.95,
    "context_json": {"duration_sec": 1500, "avg_gyro_norm": 0.012, "detector_version": "v1", "source": "motion_pipeline"}
  }]')
EPISODE_ID=$(echo $EPISODE_RESPONSE | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

# 3. Query Backboard for decision context
curl -s -X POST "${BACKBOARD_BASE_URL}/assistants/${BACKBOARD_ASSISTANT_ID}/memories/search" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query": "user:demo_user focus ritual preferences", "limit": 3}'

# 4. Log pickup_transition episode
curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/episode_log" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '[{
    "user_id": "demo_user",
    "episode_type": "pickup_transition",
    "start_ts": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "end_ts": "'$(date -u -d '+3 seconds' +%Y-%m-%dT%H:%M:%SZ)'",
    "confidence": 0.93,
    "context_json": {"accel_spike": 8.5, "gyro_spike": 1.6, "prior_episode": "face_down_stationary", "detector_version": "v1", "source": "motion_pipeline"}
  }]'

# 5. Log suggested action
ACTION_RESPONSE=$(curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/action_log" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '[{
    "user_id": "demo_user",
    "episode_id": '$EPISODE_ID',
    "action_type": "create_calendar_event",
    "action_payload": {"title": "Follow up with Alex", "start": "'$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)'"},
    "status": "suggested",
    "result_json": {"decision_source": "memory", "confidence_score": 0.85, "memory_reason": "user accepts follow-ups with person + time"}
  }]')
ACTION_ID=$(echo $ACTION_RESPONSE | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

# 6. User accepts
curl -s -X PATCH "${INSFORGE_BASE_URL}/api/database/records/action_log?id=eq.${ACTION_ID}" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"status": "accepted", "result_json": {"decision_source": "memory", "confidence_score": 0.85, "user_response": "accepted"}}'

# 7. Write outcome to Backboard
curl -s -X POST "${BACKBOARD_BASE_URL}/assistants/${BACKBOARD_ASSISTANT_ID}/memories" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "[ritual_patterns] user:demo_user completed focus ritual, accepted calendar follow-up. Pattern reinforced.",
    "metadata": {"namespace": "ritual_patterns", "user_id": "demo_user", "confidence": "0.88"}
  }'

# 8. Update user patterns
curl -s -X PATCH "${INSFORGE_BASE_URL}/api/database/records/user_patterns?user_id=eq.demo_user" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"accept_rate": 0.88, "confidence": 0.82, "last_seen": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'

echo "Focus ritual flow complete!"
```

### Scenario 2: Geofence Exit (Leave Office)

```bash
#!/bin/bash

# 1. Log geolocation sensor event (leaving office)
curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/sensor_events" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '[{
    "user_id": "demo_user",
    "sensor_type": "geolocation",
    "payload_json": {"lat": 37.7749, "lng": -122.4194, "accuracy": 10, "speed": 1.2},
    "derived_json": {"near_office": false, "exited_geofence": true, "time_of_day": "evening"}
  }]'

# 2. Log geofence_exit episode
curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/episode_log" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '[{
    "user_id": "demo_user",
    "episode_type": "geofence_exit",
    "start_ts": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "end_ts": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "confidence": 0.98,
    "context_json": {"geofence_name": "office", "exit_direction": "south", "detector_version": "v1", "source": "geolocation_pipeline"}
  }]'

# 3. Query rule match
curl -s -X GET "${INSFORGE_BASE_URL}/api/database/records/user_rules?user_id=eq.demo_user&enabled=eq.true&action_type=eq.open_maps" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}"

# 4. Query Backboard for geofence patterns
curl -s -X POST "${BACKBOARD_BASE_URL}/assistants/${BACKBOARD_ASSISTANT_ID}/memories/search" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query": "user:demo_user geofence office leave navigation", "limit": 3}'

# 5. Log auto-executed action (high confidence from rule + memory)
curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/action_log" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '[{
    "user_id": "demo_user",
    "episode_id": null,
    "action_type": "open_maps",
    "action_payload": {"destination": "home", "mode": "driving"},
    "status": "executed",
    "result_json": {"decision_source": "both", "confidence_score": 0.95, "rule_match": true, "memory_reason": "auto-accepted navigation 3/3 times", "execution_success": true}
  }]'

echo "Geofence exit flow complete!"
```

### Scenario 3: Rejected Action (Learn from Rejection)

```bash
#!/bin/bash

# 1. Log suggested action that will be rejected
ACTION_RESPONSE=$(curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/action_log" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '[{
    "user_id": "demo_user",
    "episode_id": null,
    "action_type": "send_notification",
    "action_payload": {"title": "Lunch break?", "body": "You have been working for 3 hours"},
    "status": "suggested",
    "result_json": {"decision_source": "rule", "confidence_score": 0.55, "rule_match": true}
  }]')
ACTION_ID=$(echo $ACTION_RESPONSE | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

# 2. User rejects
curl -s -X PATCH "${INSFORGE_BASE_URL}/api/database/records/action_log?id=eq.${ACTION_ID}" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"status": "rejected", "result_json": {"decision_source": "rule", "confidence_score": 0.55, "user_response": "rejected", "rejection_reason": "busy"}}'

# 3. Write negative signal to Backboard
curl -s -X POST "${BACKBOARD_BASE_URL}/assistants/${BACKBOARD_ASSISTANT_ID}/memories" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "[ritual_patterns] user:demo_user rejected lunch break notification during work hours. Lower confidence for personal reminders during focus time.",
    "metadata": {"namespace": "ritual_patterns", "user_id": "demo_user", "confidence": "0.45", "signal": "negative"}
  }'

# 4. Update user patterns (lower accept rate)
curl -s -X PATCH "${INSFORGE_BASE_URL}/api/database/records/user_patterns?user_id=eq.demo_user" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"accept_rate": 0.82, "confidence": 0.75, "last_seen": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'

echo "Rejection learning flow complete!"
```

### Scenario 4: Fall Detection Emergency Call

This simulates: sudden impact detected → post-impact stillness → fall confirmed → countdown → emergency call

```bash
#!/bin/bash
# Run from project root
# Requires: EMERGENCY_CONTACT and EMERGENCY_CONTACT_NAME in .env

source .env

# 1. Log high-impact sensor event (fall impact signature)
curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/sensor_events" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '[{
    "user_id": "demo_user",
    "sensor_type": "motion_2hz",
    "payload_json": {
      "accel_x": 15.2,
      "accel_y": -28.5,
      "accel_z": -32.1,
      "gyro_x": 2.8,
      "gyro_y": 3.2,
      "gyro_z": 1.5
    },
    "derived_json": {
      "accel_norm": 45.2,
      "gyro_norm": 4.5,
      "is_flat": false,
      "is_face_down": false,
      "impact_detected": true,
      "impact_magnitude": 45.2
    }
  }]'

# 2. Log post-impact stillness (3 seconds later)
sleep 1
curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/sensor_events" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '[{
    "user_id": "demo_user",
    "sensor_type": "motion_2hz",
    "payload_json": {
      "accel_x": 0.1,
      "accel_y": -9.7,
      "accel_z": -0.3,
      "gyro_x": 0.02,
      "gyro_y": 0.01,
      "gyro_z": 0.03
    },
    "derived_json": {
      "accel_norm": 9.71,
      "gyro_norm": 0.04,
      "is_flat": true,
      "is_face_down": false,
      "post_impact_stillness": true,
      "orientation_horizontal": true
    }
  }]'

# 3. Log fall_detected episode
EPISODE_RESPONSE=$(curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/episode_log" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '[{
    "user_id": "demo_user",
    "episode_type": "fall_detected",
    "start_ts": "'$(date -u -d '-5 seconds' +%Y-%m-%dT%H:%M:%SZ)'",
    "end_ts": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "confidence": 0.95,
    "context_json": {
      "impact_accel": 45.2,
      "post_impact_stillness_sec": 5.0,
      "orientation_change_deg": 85,
      "detector_version": "v1",
      "source": "fall_detection_pipeline"
    }
  }]')
EPISODE_ID=$(echo $EPISODE_RESPONSE | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
echo "Fall episode logged: $EPISODE_ID"

# 4. Check for fall detection rule
echo "Checking fall detection rule..."
curl -s -X GET "${INSFORGE_BASE_URL}/api/database/records/user_rules?user_id=eq.demo_user&action_type=eq.call_emergency_contact&enabled=eq.true" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}"

# 5. Log emergency call action (auto-triggered after countdown)
ACTION_RESPONSE=$(curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/action_log" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '[{
    "user_id": "demo_user",
    "episode_id": '$EPISODE_ID',
    "action_type": "call_emergency_contact",
    "action_payload": {
      "contact_number": "'${EMERGENCY_CONTACT:-+1-555-911-0000}'",
      "contact_name": "'${EMERGENCY_CONTACT_NAME:-Emergency Services}'",
      "reason": "fall_detected",
      "location": {"lat": 37.7749, "lng": -122.4194},
      "countdown_sec": 30
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
  }]')
ACTION_ID=$(echo $ACTION_RESPONSE | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
echo "Emergency call action logged: $ACTION_ID"

# 6. Write safety event to Backboard
curl -s -X POST "${BACKBOARD_BASE_URL}/assistants/${BACKBOARD_ASSISTANT_ID}/memories" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "[safety_events] user:demo_user FALL DETECTED - emergency call placed to '${EMERGENCY_CONTACT_NAME:-Emergency Services}' at '${EMERGENCY_CONTACT:-+1-555-911-0000}'. Impact: 45.2 m/s², confidence: 0.95. Location: 37.7749, -122.4194",
    "metadata": {
      "namespace": "safety_events",
      "user_id": "demo_user",
      "event_type": "fall_detected",
      "severity": "critical"
    }
  }'

echo ""
echo "==================================="
echo "FALL DETECTION FLOW COMPLETE"
echo "==================================="
echo "Episode ID: $EPISODE_ID"
echo "Action ID: $ACTION_ID"
echo "Emergency Contact: ${EMERGENCY_CONTACT:-+1-555-911-0000}"
echo "==================================="
```

### Scenario 5: Fall Detection - User Cancels (False Positive)

```bash
#!/bin/bash
# User cancels emergency call during countdown (false positive fall)

source .env

# 1. Log fall_detected episode (lower confidence)
EPISODE_RESPONSE=$(curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/episode_log" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '[{
    "user_id": "demo_user",
    "episode_type": "fall_detected",
    "start_ts": "'$(date -u -d '-3 seconds' +%Y-%m-%dT%H:%M:%SZ)'",
    "end_ts": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "confidence": 0.91,
    "context_json": {
      "impact_accel": 28.5,
      "post_impact_stillness_sec": 3.0,
      "orientation_change_deg": 45,
      "detector_version": "v1",
      "source": "fall_detection_pipeline"
    }
  }]')
EPISODE_ID=$(echo $EPISODE_RESPONSE | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

# 2. Log emergency call action as cancelled
curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/action_log" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '[{
    "user_id": "demo_user",
    "episode_id": '$EPISODE_ID',
    "action_type": "call_emergency_contact",
    "action_payload": {
      "contact_number": "'${EMERGENCY_CONTACT:-+1-555-911-0000}'",
      "contact_name": "'${EMERGENCY_CONTACT_NAME:-Emergency Services}'",
      "reason": "fall_detected"
    },
    "status": "rejected",
    "result_json": {
      "decision_source": "rule",
      "confidence_score": 0.91,
      "rule_match": true,
      "auto_triggered": true,
      "countdown_skipped": true,
      "user_response": "cancelled",
      "cancellation_reason": "false_positive"
    }
  }]'

# 3. Write false positive to Backboard (helps calibrate future detection)
curl -s -X POST "${BACKBOARD_BASE_URL}/assistants/${BACKBOARD_ASSISTANT_ID}/memories" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "[safety_events] user:demo_user fall detection FALSE POSITIVE - user cancelled emergency call. Impact: 28.5 m/s², confidence: 0.91. May need to adjust threshold for this user.",
    "metadata": {
      "namespace": "safety_events",
      "user_id": "demo_user",
      "event_type": "fall_false_positive",
      "severity": "info"
    }
  }'

echo "False positive flow complete - emergency call cancelled by user"
```

### Scenario 6: Safety Assessment with Backboard Decision

This simulates: struggle detected + location anomaly → Backboard assessment → passcode challenge → timeout → emergency call

```bash
#!/bin/bash
# Run from project root
# Full safety assessment flow with Backboard delegation

source .env

USER_ID="demo_user"
CURRENT_LAT=37.7850
CURRENT_LNG=-122.4300
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "=== SAFETY ASSESSMENT FLOW ==="
echo "Timestamp: $TIMESTAMP"
echo ""

# 1. Log location to location_history
echo "Step 1: Logging current location..."
curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/location_history" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '[{
    "user_id": "'$USER_ID'",
    "latitude": '$CURRENT_LAT',
    "longitude": '$CURRENT_LNG',
    "accuracy_meters": 15.0,
    "speed_mps": 0.5,
    "location_type": "unknown",
    "is_safe_zone": false
  }]'

# 2. Log erratic gyroscope data (struggle signature)
echo ""
echo "Step 2: Logging struggle sensor data..."
curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/sensor_events" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '[{
    "user_id": "'$USER_ID'",
    "sensor_type": "motion_2hz",
    "payload_json": {
      "accel_x": 2.5,
      "accel_y": -8.2,
      "accel_z": -4.1,
      "gyro_x": 2.8,
      "gyro_y": 3.5,
      "gyro_z": 2.1
    },
    "derived_json": {
      "accel_norm": 9.6,
      "gyro_norm": 4.9,
      "is_flat": false,
      "is_face_down": false,
      "struggle_detected": true,
      "gyro_variance_x": 2.5,
      "gyro_variance_y": 3.1,
      "gyro_variance_z": 1.8
    }
  }]'

# 3. Calculate location metrics
echo ""
echo "Step 3: Calculating location deviation..."

# Simulate centroid calculation (in real impl, query location_history)
CENTROID_LAT=37.7749
CENTROID_LNG=-122.4194
DISTANCE_FROM_CENTROID=1250  # meters
NEAREST_SAFE_ZONE=800  # meters
LOCATION_DEVIATION_SCORE=0.72

# Struggle metrics
GYRO_VAR_X=2.5
GYRO_VAR_Y=3.1
GYRO_VAR_Z=1.8
STRUGGLE_DURATION_MS=2500
STRUGGLE_INTENSITY=$(echo "scale=2; sqrt($GYRO_VAR_X^2 + $GYRO_VAR_Y^2 + $GYRO_VAR_Z^2) / 6.0 * $STRUGGLE_DURATION_MS / 3000" | bc)

echo "Distance from centroid: ${DISTANCE_FROM_CENTROID}m"
echo "Nearest safe zone: ${NEAREST_SAFE_ZONE}m"
echo "Struggle intensity: $STRUGGLE_INTENSITY"

# 4. Send assessment request to Backboard
echo ""
echo "Step 4: Requesting Backboard safety assessment..."

ASSESSMENT_PROMPT="[SAFETY_ASSESSMENT_REQUEST]
User: $USER_ID
Timestamp: $TIMESTAMP
Trigger: struggle_detected

LOCATION CONTEXT:
- Current position: ($CURRENT_LAT, $CURRENT_LNG)
- Distance from historical centroid: ${DISTANCE_FROM_CENTROID}m
- Nearest safe zone: ${NEAREST_SAFE_ZONE}m
- Location deviation score: $LOCATION_DEVIATION_SCORE

MOTION CONTEXT:
- Struggle detected: yes
- Struggle intensity: $STRUGGLE_INTENSITY
- Struggle duration: ${STRUGGLE_DURATION_MS}ms
- Gyro variance (x,y,z): ($GYRO_VAR_X, $GYRO_VAR_Y, $GYRO_VAR_Z)

HISTORICAL CONTEXT:
- Time of day: $(date +%H:%M)
- Day of week: $(date +%A)
- User typical location at this time: unknown

Based on this context and the user historical patterns in your memory, assess the safety concern level and recommend an action.

Respond in this format:
CONCERN_LEVEL: none|low|medium|high|critical
RECOMMENDED_ACTION: none|monitor|passcode_challenge|countdown_alert|immediate_call
REASONING: <brief explanation>"

BACKBOARD_RESPONSE=$(curl -s -X POST "${BACKBOARD_BASE_URL}/threads/${BACKBOARD_THREAD_ID}/messages" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "'"$(echo "$ASSESSMENT_PROMPT" | sed 's/"/\\"/g' | tr '\n' ' ')"'",
    "stream": false,
    "memory": "Auto"
  }')

echo "Backboard response:"
echo "$BACKBOARD_RESPONSE" | jq -r '.content' 2>/dev/null || echo "$BACKBOARD_RESPONSE"

# 5. Log safety assessment to InsForge
echo ""
echo "Step 5: Logging safety assessment..."

ASSESSMENT_RESPONSE=$(curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/safety_assessments" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '[{
    "user_id": "'$USER_ID'",
    "trigger_type": "struggle_detected",
    "current_lat": '$CURRENT_LAT',
    "current_lng": '$CURRENT_LNG',
    "distance_from_centroid_meters": '$DISTANCE_FROM_CENTROID',
    "nearest_safe_zone_meters": '$NEAREST_SAFE_ZONE',
    "location_deviation_score": '$LOCATION_DEVIATION_SCORE',
    "gyro_variance_x": '$GYRO_VAR_X',
    "gyro_variance_y": '$GYRO_VAR_Y',
    "gyro_variance_z": '$GYRO_VAR_Z',
    "struggle_duration_ms": '$STRUGGLE_DURATION_MS',
    "struggle_intensity_score": 0.65,
    "backboard_thread_id": "'$BACKBOARD_THREAD_ID'",
    "backboard_response": "MEDIUM concern - user at unfamiliar location with erratic movement",
    "safety_concern_level": "medium",
    "recommended_action": "passcode_challenge",
    "requires_passcode_challenge": true,
    "passcode_prompted_at": "'$TIMESTAMP'"
  }]')

ASSESSMENT_ID=$(echo "$ASSESSMENT_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
echo "Assessment ID: $ASSESSMENT_ID"

# 6. Simulate passcode timeout (60 seconds in real impl)
echo ""
echo "Step 6: Simulating passcode challenge timeout..."
TIMEOUT_TS=$(date -u -d '+60 seconds' +%Y-%m-%dT%H:%M:%SZ)

curl -s -X PATCH "${INSFORGE_BASE_URL}/api/database/records/safety_assessments?id=eq.$ASSESSMENT_ID" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "passcode_timeout_at": "'$TIMEOUT_TS'",
    "passcode_verified": false
  }'

# 7. Escalate to countdown alert
echo ""
echo "Step 7: Escalating to emergency countdown..."

# Log episode
EPISODE_RESPONSE=$(curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/episode_log" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '[{
    "user_id": "'$USER_ID'",
    "episode_type": "safety_concern",
    "start_ts": "'$TIMESTAMP'",
    "end_ts": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "confidence": 0.72,
    "context_json": {
      "trigger": "struggle_detected",
      "location_deviation": '$LOCATION_DEVIATION_SCORE',
      "struggle_intensity": 0.65,
      "backboard_concern": "medium",
      "passcode_timeout": true,
      "detector_version": "v1",
      "source": "safety_assessment_pipeline"
    }
  }]')
EPISODE_ID=$(echo "$EPISODE_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

# 8. Execute emergency call after countdown
echo ""
echo "Step 8: Executing emergency call (after 30s countdown)..."

curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/action_log" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '[{
    "user_id": "'$USER_ID'",
    "episode_id": '$EPISODE_ID',
    "action_type": "call_emergency_contact",
    "action_payload": {
      "contact_number": "'${EMERGENCY_CONTACT:-+1-555-911-0000}'",
      "contact_name": "'${EMERGENCY_CONTACT_NAME:-Emergency Services}'",
      "reason": "safety_concern_passcode_timeout",
      "location": {"lat": '$CURRENT_LAT', "lng": '$CURRENT_LNG'},
      "assessment_id": "'$ASSESSMENT_ID'"
    },
    "status": "executed",
    "result_json": {
      "decision_source": "backboard",
      "confidence_score": 0.72,
      "backboard_concern": "medium",
      "passcode_timeout": true,
      "auto_triggered": true,
      "execution_success": true
    }
  }]'

# 9. Update assessment with final action
curl -s -X PATCH "${INSFORGE_BASE_URL}/api/database/records/safety_assessments?id=eq.$ASSESSMENT_ID" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "final_action_taken": "call_emergency_contact",
    "resolved_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
  }'

# 10. Write to Backboard memory
echo ""
echo "Step 9: Writing safety event to Backboard memory..."

curl -s -X POST "${BACKBOARD_BASE_URL}/assistants/${BACKBOARD_ASSISTANT_ID}/memories" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "[safety_events] user:'$USER_ID' '$TIMESTAMP' struggle detected at unfamiliar location ('$DISTANCE_FROM_CENTROID'm from centroid), passcode timeout after 60s, emergency call placed",
    "metadata": {
      "namespace": "safety_events",
      "user_id": "'$USER_ID'",
      "event_type": "safety_concern_escalated",
      "severity": "high"
    }
  }'

echo ""
echo "==================================="
echo "SAFETY ASSESSMENT FLOW COMPLETE"
echo "==================================="
echo "Assessment ID: $ASSESSMENT_ID"
echo "Episode ID: $EPISODE_ID"
echo "Concern Level: medium"
echo "Final Action: call_emergency_contact"
echo "==================================="
```

### Scenario 7: Safety Assessment - User Verifies Passcode

```bash
#!/bin/bash
# User successfully enters passcode (false positive safety concern)

source .env

USER_ID="demo_user"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 1. Create assessment
ASSESSMENT_RESPONSE=$(curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/safety_assessments" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d '[{
    "user_id": "'$USER_ID'",
    "trigger_type": "location_anomaly",
    "current_lat": 37.8000,
    "current_lng": -122.4500,
    "distance_from_centroid_meters": 2500,
    "nearest_safe_zone_meters": 1500,
    "location_deviation_score": 0.50,
    "safety_concern_level": "low",
    "recommended_action": "passcode_challenge",
    "requires_passcode_challenge": true,
    "passcode_prompted_at": "'$TIMESTAMP'"
  }]')
ASSESSMENT_ID=$(echo "$ASSESSMENT_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

# 2. User enters correct passcode within 60s
curl -s -X PATCH "${INSFORGE_BASE_URL}/api/database/records/safety_assessments?id=eq.$ASSESSMENT_ID" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "passcode_verified": true,
    "false_positive": true,
    "final_action_taken": "none",
    "resolved_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "user_feedback": "Was at new coffee shop"
  }'

# 3. Write false positive to Backboard (helps learn new safe locations)
curl -s -X POST "${BACKBOARD_BASE_URL}/assistants/${BACKBOARD_ASSISTANT_ID}/memories" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "[safety_events] user:'$USER_ID' '$TIMESTAMP' location anomaly false positive - user verified passcode at new location (2.5km from centroid). User feedback: was at new coffee shop",
    "metadata": {
      "namespace": "safety_events",
      "user_id": "'$USER_ID'",
      "event_type": "location_anomaly_false_positive",
      "severity": "info"
    }
  }'

# 4. Optionally mark new location as safe zone
echo "Marking new location as potential safe zone..."
curl -s -X POST "${INSFORGE_BASE_URL}/api/database/records/location_history" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '[{
    "user_id": "'$USER_ID'",
    "latitude": 37.8000,
    "longitude": -122.4500,
    "location_type": "routine",
    "is_safe_zone": true,
    "visit_count": 1
  }]'

echo "Passcode verified - false positive recorded"
```

---

## Jac Integration Patterns

### Pattern 1: HTTP Request from Jac

```jac
# Using shell to make curl requests
can log_sensor_event(payload: dict) -> dict {
    import:py subprocess;
    import:py os;
    
    base_url = os.getenv("INSFORGE_BASE_URL", "");
    anon_key = os.getenv("INSFORGE_ANON_KEY", "");
    
    cmd = f'''curl -s -X POST "{base_url}/api/database/records/sensor_events" \
        -H "Authorization: Bearer {anon_key}" \
        -H "Content-Type: application/json" \
        -d '[{json.dumps(payload)}]' ''';
    
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True);
    return json.loads(result.stdout);
}
```

### Pattern 2: Memory-Assisted Decision

```jac
# Query Backboard for decision context
can get_decision_context(user_id: str, query: str) -> list {
    import:py subprocess;
    import:py json;
    import:py os;
    
    base_url = os.getenv("BACKBOARD_BASE_URL", "https://app.backboard.io/api");
    api_key = os.getenv("BACKBOARD_KEY", "");
    assistant_id = os.getenv("BACKBOARD_ASSISTANT_ID", "");
    
    cmd = f'''curl -s -X POST "{base_url}/assistants/{assistant_id}/memories/search" \
        -H "X-API-Key: {api_key}" \
        -H "Content-Type: application/json" \
        -d '{{"query": "user:{user_id} {query}", "limit": 5}}' ''';
    
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True);
    data = json.loads(result.stdout);
    return data.get("memories", []);
}
```

### Pattern 3: Agent Decision Loop

```jac
walker agent_cycle {
    can decide with episode entry {
        # 1. Get episode context
        episode_type = here.episode_type;
        user_id = here.user_id;
        
        # 2. Query memories
        memories = get_decision_context(user_id, f"{episode_type} preferences");
        
        # 3. Query rules
        rules = query_rules(user_id, episode_type);
        
        # 4. Compute confidence
        memory_signal = memories[0].score if memories else 0.0;
        rule_match = len(rules) > 0;
        confidence = compute_confidence(memory_signal, rule_match);
        
        # 5. Decide and log
        if confidence >= 0.8 and auto_mode {
            execute_action(action);
            log_action(user_id, action, "executed", confidence);
        } else {
            suggest_action(action);
            log_action(user_id, action, "suggested", confidence);
        }
        
        # 6. Write outcome to memory
        write_outcome(user_id, episode_type, action, confidence);
    }
}
```

### Pattern 4: Fall Detection Walker

```jac
import:py os;
import:py subprocess;
import:py json;

# Fall detection thresholds
glob IMPACT_THRESHOLD = 25.0;      # m/s² (3G+)
glob STILLNESS_THRESHOLD = 0.1;    # rad/s
glob STILLNESS_DURATION = 3.0;     # seconds
glob ORIENTATION_THRESHOLD = 60.0; # degrees
glob CONFIDENCE_THRESHOLD = 0.90;
glob COUNTDOWN_SEC = 30;

node sensor_sample {
    has accel_norm: float;
    has gyro_norm: float;
    has orientation_deg: float;
    has timestamp: float;
}

node fall_event {
    has user_id: str;
    has impact_accel: float;
    has stillness_sec: float;
    has orientation_change: float;
    has confidence: float;
    has location: dict;
}

walker fall_detector {
    has recent_samples: list = [];
    has impact_detected: bool = False;
    has impact_time: float = 0.0;
    has impact_accel: float = 0.0;
    
    can process_sample with sensor_sample entry {
        # Add to rolling window
        self.recent_samples.append(here);
        if len(self.recent_samples) > 10 {
            self.recent_samples.pop(0);
        }
        
        # Check for impact spike
        if here.accel_norm > IMPACT_THRESHOLD and not self.impact_detected {
            self.impact_detected = True;
            self.impact_time = here.timestamp;
            self.impact_accel = here.accel_norm;
            print(f"IMPACT DETECTED: {here.accel_norm} m/s²");
        }
        
        # Check for post-impact stillness
        if self.impact_detected {
            time_since_impact = here.timestamp - self.impact_time;
            
            if time_since_impact >= STILLNESS_DURATION {
                # Check if still during window
                stillness_samples = [s for s in self.recent_samples 
                                    if s.timestamp > self.impact_time 
                                    and s.gyro_norm < STILLNESS_THRESHOLD];
                
                if len(stillness_samples) >= 3 {
                    # Compute confidence
                    confidence = self.compute_fall_confidence(
                        self.impact_accel,
                        len(stillness_samples),
                        here.orientation_deg
                    );
                    
                    if confidence >= CONFIDENCE_THRESHOLD {
                        # Trigger fall event
                        fall = fall_event(
                            user_id="demo_user",
                            impact_accel=self.impact_accel,
                            stillness_sec=time_since_impact,
                            orientation_change=here.orientation_deg,
                            confidence=confidence,
                            location={"lat": 37.7749, "lng": -122.4194}
                        );
                        visit fall;
                    }
                }
                
                # Reset detector
                self.impact_detected = False;
            }
        }
    }
    
    can compute_fall_confidence(impact: float, stillness_count: int, orientation: float) -> float {
        score = 0.0;
        
        # Impact contribution (0.4 max)
        if impact > IMPACT_THRESHOLD {
            score += 0.4 * min(impact / 50.0, 1.0);
        }
        
        # Stillness contribution (0.3 max)
        score += 0.3 * min(stillness_count / 5.0, 1.0);
        
        # Orientation contribution (0.3 max)
        if orientation > ORIENTATION_THRESHOLD {
            score += 0.3 * min(orientation / 90.0, 1.0);
        }
        
        return score;
    }
    
    can trigger_emergency with fall_event entry {
        print(f"FALL CONFIRMED - Confidence: {here.confidence}");
        print(f"Starting {COUNTDOWN_SEC}s countdown...");
        
        # Get emergency contact from env
        emergency_contact = os.getenv("EMERGENCY_CONTACT", "+1-555-911-0000");
        emergency_name = os.getenv("EMERGENCY_CONTACT_NAME", "Emergency Services");
        
        # Log episode to InsForge
        episode_id = self.log_fall_episode(here);
        
        # Execute emergency call (after countdown in real impl)
        self.execute_emergency_call(here, episode_id, emergency_contact, emergency_name);
        
        # Write to Backboard
        self.write_safety_memory(here, emergency_contact);
    }
    
    can log_fall_episode(fall: fall_event) -> str {
        import:py subprocess;
        import:py json;
        import:py datetime;
        
        now = datetime.datetime.utcnow().isoformat() + "Z";
        base_url = os.getenv("INSFORGE_BASE_URL", "");
        anon_key = os.getenv("INSFORGE_ANON_KEY", "");
        
        payload = [{
            "user_id": fall.user_id,
            "episode_type": "fall_detected",
            "start_ts": now,
            "end_ts": now,
            "confidence": fall.confidence,
            "context_json": {
                "impact_accel": fall.impact_accel,
                "post_impact_stillness_sec": fall.stillness_sec,
                "orientation_change_deg": fall.orientation_change,
                "detector_version": "v1",
                "source": "fall_detection_pipeline"
            }
        }];
        
        cmd = f'''curl -s -X POST "{base_url}/api/database/records/episode_log" \
            -H "Authorization: Bearer {anon_key}" \
            -H "Content-Type: application/json" \
            -H "Prefer: return=representation" \
            -d '{json.dumps(payload)}' ''';
        
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True);
        data = json.loads(result.stdout);
        return data[0].get("id", "unknown");
    }
    
    can execute_emergency_call(fall: fall_event, episode_id: str, contact: str, name: str) {
        import:py subprocess;
        import:py json;
        
        base_url = os.getenv("INSFORGE_BASE_URL", "");
        anon_key = os.getenv("INSFORGE_ANON_KEY", "");
        
        payload = [{
            "user_id": fall.user_id,
            "episode_id": int(episode_id) if episode_id.isdigit() else None,
            "action_type": "call_emergency_contact",
            "action_payload": {
                "contact_number": contact,
                "contact_name": name,
                "reason": "fall_detected",
                "location": fall.location
            },
            "status": "executed",
            "result_json": {
                "decision_source": "rule",
                "confidence_score": fall.confidence,
                "rule_match": True,
                "auto_triggered": True,
                "execution_success": True
            }
        }];
        
        cmd = f'''curl -s -X POST "{base_url}/api/database/records/action_log" \
            -H "Authorization: Bearer {anon_key}" \
            -H "Content-Type: application/json" \
            -d '{json.dumps(payload)}' ''';
        
        subprocess.run(cmd, shell=True, capture_output=True, text=True);
        print(f"Emergency call placed to {name} at {contact}");
    }
    
    can write_safety_memory(fall: fall_event, contact: str) {
        import:py subprocess;
        import:py json;
        
        base_url = os.getenv("BACKBOARD_BASE_URL", "https://app.backboard.io/api");
        api_key = os.getenv("BACKBOARD_KEY", "");
        assistant_id = os.getenv("BACKBOARD_ASSISTANT_ID", "");
        
        content = f"[safety_events] user:{fall.user_id} FALL DETECTED - emergency call placed. Impact: {fall.impact_accel} m/s², confidence: {fall.confidence}";
        
        payload = {
            "content": content,
            "metadata": {
                "namespace": "safety_events",
                "user_id": fall.user_id,
                "event_type": "fall_detected",
                "severity": "critical"
            }
        };
        
        cmd = f'''curl -s -X POST "{base_url}/assistants/{assistant_id}/memories" \
            -H "X-API-Key: {api_key}" \
            -H "Content-Type: application/json" \
            -d '{json.dumps(payload)}' ''';
        
        subprocess.run(cmd, shell=True, capture_output=True, text=True);
    }
}
```

### Pattern 5: Safety Assessment Walker (Backboard-Delegated)

```jac
import:py os;
import:py subprocess;
import:py json;
import:py math;
import:py datetime;

# Safety assessment thresholds
glob GYRO_VARIANCE_THRESHOLD = 1.5;    # rad/s² per axis
glob STRUGGLE_MIN_DURATION_MS = 500;
glob STRUGGLE_MAX_DURATION_MS = 5000;
glob LOCATION_DEVIATION_MAX_M = 5000;  # 5km = max concern
glob PASSCODE_TIMEOUT_SEC = 60;
glob COUNTDOWN_SEC = 30;

# Backboard config (from environment)
glob BACKBOARD_BASE_URL = os.getenv("BACKBOARD_BASE_URL", "https://app.backboard.io/api");
glob BACKBOARD_ASSISTANT_ID = os.getenv("BACKBOARD_ASSISTANT_ID", "");
glob BACKBOARD_THREAD_ID = os.getenv("BACKBOARD_THREAD_ID", "");

# InsForge config (from environment)
glob INSFORGE_BASE_URL = os.getenv("INSFORGE_BASE_URL", "");

node location_sample {
    has lat: float;
    has lng: float;
    has accuracy_m: float;
    has timestamp: float;
}

node gyro_sample {
    has variance_x: float;
    has variance_y: float;
    has variance_z: float;
    has duration_ms: int;
    has timestamp: float;
}

node safety_context {
    has user_id: str;
    has trigger_type: str;
    has current_location: dict;
    has location_metrics: dict;
    has struggle_metrics: dict;
    has time_context: dict;
}

node backboard_decision {
    has concern_level: str;
    has recommended_action: str;
    has reasoning: str;
    has raw_response: str;
}

walker safety_assessor {
    has location_history: list = [];
    has gyro_window: list = [];
    
    # Haversine distance calculation
    can haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float {
        R = 6371000;  # Earth radius in meters
        phi1 = math.radians(lat1);
        phi2 = math.radians(lat2);
        delta_phi = math.radians(lat2 - lat1);
        delta_lambda = math.radians(lng2 - lng1);
        
        a = math.sin(delta_phi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda/2)**2;
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
        
        return R * c;
    }
    
    # Calculate location centroid from history
    can get_location_centroid(user_id: str) -> dict {
        # In real impl, query InsForge location_history
        # For now, return mock centroid
        return {"lat": 37.7749, "lng": -122.4194};
    }
    
    # Find nearest safe zone
    can get_nearest_safe_zone(user_id: str, current_lat: float, current_lng: float) -> float {
        # In real impl, query location_history WHERE is_safe_zone = true
        # Return distance to nearest safe zone
        return 800.0;  # Mock: 800m to nearest safe zone
    }
    
    # Calculate struggle intensity from gyro variance
    can calculate_struggle_intensity(var_x: float, var_y: float, var_z: float, duration_ms: int) -> float {
        variance_total = math.sqrt(var_x**2 + var_y**2 + var_z**2);
        return min(1.0, (variance_total / 6.0) * (duration_ms / 3000.0));
    }
    
    # Detect struggle pattern from gyro samples
    can detect_struggle with gyro_sample entry {
        self.gyro_window.append(here);
        if len(self.gyro_window) > 20 {
            self.gyro_window.pop(0);
        }
        
        # Check for multi-axis instability
        axes_over_threshold = 0;
        if here.variance_x > GYRO_VARIANCE_THRESHOLD { axes_over_threshold += 1; }
        if here.variance_y > GYRO_VARIANCE_THRESHOLD { axes_over_threshold += 1; }
        if here.variance_z > GYRO_VARIANCE_THRESHOLD { axes_over_threshold += 1; }
        
        if axes_over_threshold >= 2 and here.duration_ms >= STRUGGLE_MIN_DURATION_MS {
            # Struggle detected - trigger safety assessment
            intensity = self.calculate_struggle_intensity(
                here.variance_x, here.variance_y, here.variance_z, here.duration_ms
            );
            
            if intensity > 0.4 {
                print(f"STRUGGLE DETECTED: intensity={intensity}");
                # Create safety context and visit
                ctx = safety_context(
                    user_id="demo_user",
                    trigger_type="struggle_detected",
                    current_location={"lat": 37.7850, "lng": -122.4300},  # From GPS
                    location_metrics={},
                    struggle_metrics={
                        "variance_x": here.variance_x,
                        "variance_y": here.variance_y,
                        "variance_z": here.variance_z,
                        "duration_ms": here.duration_ms,
                        "intensity": intensity
                    },
                    time_context={
                        "time": datetime.datetime.now().strftime("%H:%M"),
                        "day": datetime.datetime.now().strftime("%A")
                    }
                );
                visit ctx;
            }
        }
    }
    
    # Check for location anomaly
    can check_location with location_sample entry {
        centroid = self.get_location_centroid("demo_user");
        distance = self.haversine(here.lat, here.lng, centroid["lat"], centroid["lng"]);
        deviation_score = min(1.0, distance / LOCATION_DEVIATION_MAX_M);
        
        if deviation_score > 0.5 {  # More than 2.5km from centroid
            print(f"LOCATION ANOMALY: {distance}m from centroid");
            
            nearest_safe = self.get_nearest_safe_zone("demo_user", here.lat, here.lng);
            
            ctx = safety_context(
                user_id="demo_user",
                trigger_type="location_anomaly",
                current_location={"lat": here.lat, "lng": here.lng},
                location_metrics={
                    "distance_from_centroid": distance,
                    "deviation_score": deviation_score,
                    "nearest_safe_zone": nearest_safe
                },
                struggle_metrics={},
                time_context={
                    "time": datetime.datetime.now().strftime("%H:%M"),
                    "day": datetime.datetime.now().strftime("%A")
                }
            );
            visit ctx;
        }
    }
    
    # Request Backboard assessment
    can request_assessment with safety_context entry {
        print(f"Requesting Backboard assessment for {here.trigger_type}...");
        
        # Build assessment prompt
        prompt = self.build_assessment_prompt(here);
        
        # Send to Backboard
        response = self.send_to_backboard(prompt);
        
        # Parse response
        decision = self.parse_backboard_response(response);
        decision.raw_response = response;
        
        # Log to InsForge
        assessment_id = self.log_assessment(here, decision);
        
        print(f"Backboard decision: {decision.concern_level} -> {decision.recommended_action}");
        
        # Execute recommended action
        if decision.recommended_action == "passcode_challenge" {
            self.execute_passcode_challenge(here, decision, assessment_id);
        } elif decision.recommended_action == "countdown_alert" {
            self.execute_countdown_alert(here, decision, assessment_id);
        } elif decision.recommended_action == "immediate_call" {
            self.execute_emergency_call(here, decision, assessment_id);
        }
    }
    
    can build_assessment_prompt(ctx: safety_context) -> str {
        prompt = f"""[SAFETY_ASSESSMENT_REQUEST]
User: {ctx.user_id}
Timestamp: {datetime.datetime.utcnow().isoformat()}Z
Trigger: {ctx.trigger_type}

LOCATION CONTEXT:
- Current position: ({ctx.current_location.get('lat', 0)}, {ctx.current_location.get('lng', 0)})
- Distance from historical centroid: {ctx.location_metrics.get('distance_from_centroid', 'unknown')}m
- Nearest safe zone: {ctx.location_metrics.get('nearest_safe_zone', 'unknown')}m
- Location deviation score: {ctx.location_metrics.get('deviation_score', 0)}

MOTION CONTEXT:
- Struggle detected: {'yes' if ctx.struggle_metrics else 'no'}
- Struggle intensity: {ctx.struggle_metrics.get('intensity', 0)}
- Struggle duration: {ctx.struggle_metrics.get('duration_ms', 0)}ms
- Gyro variance (x,y,z): ({ctx.struggle_metrics.get('variance_x', 0)}, {ctx.struggle_metrics.get('variance_y', 0)}, {ctx.struggle_metrics.get('variance_z', 0)})

HISTORICAL CONTEXT:
- Time of day: {ctx.time_context.get('time', 'unknown')}
- Day of week: {ctx.time_context.get('day', 'unknown')}

Based on this context and the user's historical patterns in your memory, assess the safety concern level and recommend an action.

Respond in this format:
CONCERN_LEVEL: none|low|medium|high|critical
RECOMMENDED_ACTION: none|monitor|passcode_challenge|countdown_alert|immediate_call
REASONING: <brief explanation>""";
        
        return prompt;
    }
    
    can send_to_backboard(prompt: str) -> str {
        import:py subprocess;
        import:py json;
        
        payload = {
            "content": prompt,
            "stream": False,
            "memory": "Auto"
        };
        
        cmd = f'''curl -s -X POST "{BACKBOARD_BASE_URL}/threads/{BACKBOARD_THREAD_ID}/messages" \
            -H "X-API-Key: {os.getenv('BACKBOARD_KEY')}" \
            -H "Content-Type: application/json" \
            -d '{json.dumps(payload)}' ''';
        
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True);
        data = json.loads(result.stdout);
        return data.get("content", "");
    }
    
    can parse_backboard_response(response: str) -> backboard_decision {
        # Parse structured response from Backboard
        concern = "medium";  # Default
        action = "passcode_challenge";
        reasoning = "";
        
        lines = response.split("\n");
        for line in lines {
            if line.startswith("CONCERN_LEVEL:") {
                concern = line.split(":")[1].strip().lower();
            } elif line.startswith("RECOMMENDED_ACTION:") {
                action = line.split(":")[1].strip().lower();
            } elif line.startswith("REASONING:") {
                reasoning = line.split(":", 1)[1].strip();
            }
        }
        
        return backboard_decision(
            concern_level=concern,
            recommended_action=action,
            reasoning=reasoning,
            raw_response=""
        );
    }
    
    can log_assessment(ctx: safety_context, decision: backboard_decision) -> str {
        import:py subprocess;
        import:py json;
        
        payload = [{
            "user_id": ctx.user_id,
            "trigger_type": ctx.trigger_type,
            "current_lat": ctx.current_location.get("lat"),
            "current_lng": ctx.current_location.get("lng"),
            "distance_from_centroid_meters": ctx.location_metrics.get("distance_from_centroid"),
            "nearest_safe_zone_meters": ctx.location_metrics.get("nearest_safe_zone"),
            "location_deviation_score": ctx.location_metrics.get("deviation_score"),
            "gyro_variance_x": ctx.struggle_metrics.get("variance_x"),
            "gyro_variance_y": ctx.struggle_metrics.get("variance_y"),
            "gyro_variance_z": ctx.struggle_metrics.get("variance_z"),
            "struggle_duration_ms": ctx.struggle_metrics.get("duration_ms"),
            "struggle_intensity_score": ctx.struggle_metrics.get("intensity"),
            "backboard_thread_id": BACKBOARD_THREAD_ID,
            "backboard_response": decision.raw_response[:500] if decision.raw_response else "",
            "safety_concern_level": decision.concern_level,
            "recommended_action": decision.recommended_action,
            "requires_passcode_challenge": decision.recommended_action == "passcode_challenge"
        }];
        
        cmd = f'''curl -s -X POST "{INSFORGE_BASE_URL}/api/database/records/safety_assessments" \
            -H "Authorization: Bearer {os.getenv('INSFORGE_ANON_KEY')}" \
            -H "Content-Type: application/json" \
            -H "Prefer: return=representation" \
            -d '{json.dumps(payload)}' ''';
        
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True);
        data = json.loads(result.stdout);
        return data[0].get("id", "unknown") if data else "unknown";
    }
    
    can execute_passcode_challenge(ctx: safety_context, decision: backboard_decision, assessment_id: str) {
        print(f"PASSCODE CHALLENGE: User has {PASSCODE_TIMEOUT_SEC}s to verify");
        # In real impl:
        # 1. Show passcode prompt UI
        # 2. Start 60s timer
        # 3. If verified -> mark false_positive, write to Backboard
        # 4. If timeout -> escalate to countdown_alert
    }
    
    can execute_countdown_alert(ctx: safety_context, decision: backboard_decision, assessment_id: str) {
        print(f"COUNTDOWN ALERT: {COUNTDOWN_SEC}s until emergency call");
        # In real impl:
        # 1. Show countdown UI
        # 2. If cancelled -> mark false_positive
        # 3. If timeout -> execute_emergency_call
    }
    
    can execute_emergency_call(ctx: safety_context, decision: backboard_decision, assessment_id: str) {
        import:py subprocess;
        import:py json;
        
        emergency_contact = os.getenv("EMERGENCY_CONTACT", "+1-555-911-0000");
        emergency_name = os.getenv("EMERGENCY_CONTACT_NAME", "Emergency Services");
        
        print(f"EMERGENCY CALL: Calling {emergency_name} at {emergency_contact}");
        
        # Log action
        payload = [{
            "user_id": ctx.user_id,
            "action_type": "call_emergency_contact",
            "action_payload": {
                "contact_number": emergency_contact,
                "contact_name": emergency_name,
                "reason": ctx.trigger_type,
                "location": ctx.current_location,
                "assessment_id": assessment_id
            },
            "status": "executed",
            "result_json": {
                "decision_source": "backboard",
                "confidence_score": ctx.location_metrics.get("deviation_score", 0) + ctx.struggle_metrics.get("intensity", 0),
                "backboard_concern": decision.concern_level,
                "auto_triggered": True,
                "execution_success": True
            }
        }];
        
        cmd = f'''curl -s -X POST "{INSFORGE_BASE_URL}/api/database/records/action_log" \
            -H "Authorization: Bearer {os.getenv('INSFORGE_ANON_KEY')}" \
            -H "Content-Type: application/json" \
            -d '{json.dumps(payload)}' ''';
        
        subprocess.run(cmd, shell=True, capture_output=True, text=True);
        
        # Write to Backboard memory
        self.write_safety_memory(ctx, decision, "emergency_call_placed");
    }
    
    can write_safety_memory(ctx: safety_context, decision: backboard_decision, outcome: str) {
        import:py subprocess;
        import:py json;
        
        content = f"[safety_events] user:{ctx.user_id} {datetime.datetime.utcnow().isoformat()}Z {ctx.trigger_type} -> {decision.concern_level} concern -> {outcome}";
        
        payload = {
            "content": content,
            "metadata": {
                "namespace": "safety_events",
                "user_id": ctx.user_id,
                "event_type": ctx.trigger_type,
                "outcome": outcome
            }
        };
        
        cmd = f'''curl -s -X POST "{BACKBOARD_BASE_URL}/assistants/{BACKBOARD_ASSISTANT_ID}/memories" \
            -H "X-API-Key: {os.getenv('BACKBOARD_KEY')}" \
            -H "Content-Type: application/json" \
            -d '{json.dumps(payload)}' ''';
        
        subprocess.run(cmd, shell=True, capture_output=True, text=True);
    }
}
```

---

## Quick Verification Queries

### Check InsForge Data

```bash
# Count all records
curl -s "${INSFORGE_BASE_URL}/api/database/records/sensor_events?select=id&limit=1" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" -I | grep X-Total-Count

curl -s "${INSFORGE_BASE_URL}/api/database/records/episode_log?select=id&limit=1" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" -I | grep X-Total-Count

curl -s "${INSFORGE_BASE_URL}/api/database/records/action_log?select=id&limit=1" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}" -I | grep X-Total-Count

# Recent episodes
curl -s "${INSFORGE_BASE_URL}/api/database/records/episode_log?order=end_ts.desc&limit=5" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}"

# Recent actions
curl -s "${INSFORGE_BASE_URL}/api/database/records/action_log?order=ts.desc&limit=5" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}"

# All user rules
curl -s "${INSFORGE_BASE_URL}/api/database/records/user_rules?user_id=eq.demo_user" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}"

# User patterns
curl -s "${INSFORGE_BASE_URL}/api/database/records/user_patterns?user_id=eq.demo_user" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}"

# User integrations
curl -s "${INSFORGE_BASE_URL}/api/database/records/user_integrations?user_id=eq.demo_user" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}"
```

### Check Location History Data

```bash
# All safe zones
curl -s "${INSFORGE_BASE_URL}/api/database/records/location_history?user_id=eq.demo_user&is_safe_zone=eq.true" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}"

# Recent locations
curl -s "${INSFORGE_BASE_URL}/api/database/records/location_history?user_id=eq.demo_user&order=last_seen_at.desc&limit=10" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}"

# Location centroid (approximate via SQL)
# Use raw SQL for actual centroid calculation
```

### Check Safety Assessments

```bash
# Recent assessments
curl -s "${INSFORGE_BASE_URL}/api/database/records/safety_assessments?user_id=eq.demo_user&order=created_at.desc&limit=10" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}"

# Unresolved assessments (pending passcode verification)
curl -s "${INSFORGE_BASE_URL}/api/database/records/safety_assessments?user_id=eq.demo_user&resolved_at=is.null" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}"

# False positives (for calibration analysis)
curl -s "${INSFORGE_BASE_URL}/api/database/records/safety_assessments?user_id=eq.demo_user&false_positive=eq.true" \
  -H "Authorization: Bearer ${INSFORGE_ANON_KEY}"
```

### Check Backboard Data

```bash
# List all memories
curl -s "${BACKBOARD_BASE_URL}/assistants/${BACKBOARD_ASSISTANT_ID}/memories" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}"

# Search safety event memories
curl -s -X POST "${BACKBOARD_BASE_URL}/assistants/${BACKBOARD_ASSISTANT_ID}/memories/search" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query": "safety_events user:demo_user", "limit": 10}'

# Get thread history
curl -s "${BACKBOARD_BASE_URL}/threads/${BACKBOARD_THREAD_ID}" \
  -H "X-API-Key: ${BACKBOARD_API_KEY}"
```

---

## Environment Setup

Add to your shell profile or source before running:

```bash
# Create .env file from template (fill in your actual credentials)
cat > .env << 'EOF'
# InsForge Backend
INSFORGE_BASE_URL=https://your-project.region.insforge.app
INSFORGE_ANON_KEY=<your-insforge-anon-key>

# Backboard Memory
BACKBOARD_BASE_URL=https://app.backboard.io/api
BACKBOARD_KEY=<your-backboard-api-key>
BACKBOARD_ASSISTANT_ID=<your-backboard-assistant-id>
BACKBOARD_THREAD_ID=<your-backboard-thread-id>

# Emergency Contact (Safety Features)
EMERGENCY_CONTACT=+1-555-911-0000
EMERGENCY_CONTACT_NAME=Emergency Services
EOF

# Source the environment
set -a && source .env && set +a

# Verify setup
echo "InsForge URL: $INSFORGE_BASE_URL"
echo "Backboard Assistant: $BACKBOARD_ASSISTANT_ID"
echo "Emergency Contact: $EMERGENCY_CONTACT"
```

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `INSFORGE_BASE_URL` | InsForge API base URL | `https://your-project.region.insforge.app` |
| `INSFORGE_ANON_KEY` | InsForge anonymous JWT token | (get from InsForge dashboard) |
| `BACKBOARD_BASE_URL` | Backboard API base URL | `https://app.backboard.io/api` |
| `BACKBOARD_KEY` | Backboard API key | (get from Backboard dashboard) |
| `BACKBOARD_ASSISTANT_ID` | Backboard assistant UUID | (create via API or dashboard) |
| `BACKBOARD_THREAD_ID` | Backboard conversation thread UUID | (create via API) |
| `EMERGENCY_CONTACT` | Phone number for emergency calls | `+1-555-911-0000` |
| `EMERGENCY_CONTACT_NAME` | Display name for emergency contact | `Emergency Services` |

### Getting Credentials

1. **InsForge**: 
   - Base URL and anon key are pre-configured for this project
   - For new projects, use `insforge_get-backend-metadata` MCP tool

2. **Backboard**:
   - API key available from Backboard.io dashboard
   - Assistant and thread IDs created via `POST /assistants` and `POST /threads`

3. **Emergency Contact**:
   - Set to actual emergency contact for production use
   - Demo uses placeholder number

