# Hijac — Product Requirements Document

## 1. Overview
Hijac is a mobile-first application that Hijacs your daily routine to do things for you. It reads sensor data from your phone in real time—location, gyroscope, accelerometer, time, and more—and uses an AI agent or user-defined automation rules to perform tasks on your behalf without you having to think about it.

Hijac is built on top of the Jac Lang agentic framework, compiled to a Progressive Web App (PWA) using Capacitor for access to native device sensors on Android (Samsung Galaxy S23+), with InsForge as the backend infrastructure and **Backboard.ai** powering the persistent memory layer for the agent.

## 2. Goals
* Deliver a working demo that reads at least two sensor inputs (location + one analog sensor) and triggers a real action.
* Get a Jac Lang client running on mobile via Capacitor/PWA.
* Integrate InsForge as the backend (database, auth, functions)—the agent's persistence layer.
* Integrate **Backboard.ai** as the agent's persistent memory layer so it can reason about patterns over time and solve "AI amnesia."
* Win sponsor tracks for Jac Lang, InsForge, and Backboard.ai.

## 3. Tech Stack

| Layer | Technology |
| :--- | :--- |
| **Mobile Compilation** | Capacitor (PWA → native Android wrapper) |
| **Sensor APIs** | Capacitor plugins: Geolocation, Motion, Device |
| **Frontend** | Web app (React or vanilla JS) |
| **Agentic Framework** | Jac Lang (primary) |
| **Backend Infra** | InsForge (DB, auth, storage, edge functions, model gateway) |
| **Agent Memory** | Backboard.ai |
| **Target Device** | Samsung Galaxy S23 (Android) |

## 4. Architecture

```text
[Sensor Layer]           [App Layer]              [Agent Layer]
  Geolocation      →                          →   Jac Lang Agent
  Gyroscope        →   Capacitor PWA (React)  →      ↕
  Accelerometer    →                          →   Backboard.ai (memory)
  Time/Calendar    →                          →      ↕
                                              →   InsForge (DB + functions)
                                                       ↓
                                               [Action Execution]
                                               Maps, Calendar, Notifications,
                                               HTTP webhooks, etc.
```

**Data Flow:**
1.  Capacitor plugins poll or subscribe to sensor events.
2.  Sensor data is sent to the Jac Lang agent via an InsForge edge function.
3.  The agent queries Backboard.ai for historical context, persistent state, and learned patterns.
4.  The agent evaluates user-defined rules + AI reasoning to decide whether to trigger an action.
5.  Actions are executed (deep links, API calls, notifications).
6.  Results are logged back to InsForge, and Backboard.ai automatically updates its memory engine.

## 5. Core Features

### Feature 1 — Sensor Ingestion
Read sensor data from the device continuously or at intervals. 
**Sensors to support (v1):**
* GPS / Geolocation (lat/lng, speed, accuracy)
* Gyroscope (device orientation, angular velocity)
* Accelerometer (motion, steps, shakes)
* System time + calendar (day of week, time of day)

### Feature 2 — Trigger Rules Engine
Users can define simple "if sensor → then action" automation rules without AI, like a personal IFTTT. These are evaluated client-side or via InsForge edge functions.
**Example rules:**
* `IF location ≈ office AND time > 17:00 THEN open_maps_home`
* `IF device_is_shaken AND time < 08:00 THEN send_snooze_message`
* `IF walking_speed > 0 AND location = gym_area THEN log_workout_start`

### Feature 3 — AI Agent (Jac Lang)
An AI agent that goes beyond static rules. The agent observes sensor patterns over time (via Backboard.ai memory), infers context, and proactively takes actions or makes suggestions.
**Agent capabilities:**
* **Pattern detection:** "You always leave work at 5:10 PM on Tuesdays."
* **Contextual reasoning:** "Your phone is oriented portrait + you're walking + it's 5 PM = commute home."
* **Proactive suggestion:** "Want me to set your route home?"
* **Autonomous execution:** Takes the action without prompting (if the user has enabled auto-mode).

### Feature 4 — Action Library
A set of supported output actions the agent or rules can trigger.
**v1 actions:**
* Open Google Maps with destination pre-filled (deep link)
* Send a local push notification
* Post a webhook (generic HTTP POST with sensor payload)
* Log an event to InsForge DB (for history and pattern learning)

### Feature 5 — User Configuration UI
Simple mobile UI where the user can:
* View live sensor data (debug panel)
* Create and manage automation rules
* Enable/disable AI auto-mode
* View action history

## 6. Sponsor Track Integration

### 6A — Jac Lang (Primary Framework)
Jac Lang provides the agentic framework that powers Hijac's intelligence layer. This is the core of the project.
**Integration tasks:**
* Get the Jac Lang JS/TS client running in a Capacitor-wrapped web view on Android.
* Define the agent's system prompt with context about available sensors and actions.
* Wire sensor payloads into the agent's context window on each significant event.
* Define tool functions the agent can call (`trigger_maps`, `send_notification`, `log_event`, etc.).
* Test end-to-end: sensor input → agent reasoning → action execution.

**Why it fits:** Jac Lang is literally the brain of Hijac. The hackathon is sponsored by them, and Hijac is built ground-up on their framework. This is not a sprinkled integration—it's structural.

### 6B — InsForge (Backend for Agentic Development)
InsForge is a backend platform built for AI agents. It exposes databases, auth, storage, and edge functions through a semantic layer that agents can understand and operate directly. Think of it as "Supabase but the agent drives."
**Integration tasks:**
* Set up an InsForge project (cloud).
* Create a `sensor_events` table: `{ user_id, sensor_type, value, timestamp }`.
* Create a `user_rules` table: `{ user_id, trigger_condition, action_type, action_params, enabled }`.
* Create an `action_log` table: `{ user_id, triggered_at, rule_or_agent, action_taken, result }`.
* Expose an InsForge edge function `evaluate_rules(sensor_payload)` that the Capacitor app calls on each sensor event.
* Let the Jac Lang agent call InsForge directly to read/write user history.
* Auth: use InsForge auth to identify the user's device session.

**Why it fits:** InsForge was built exactly for this—AI agents that need to ship full-stack apps with a persistent backend. The agent querying and writing to InsForge directly is the ideal demo of their platform.

### 6C — Backboard.ai (Persistent Memory Layer)
Backboard.ai serves as the persistent memory layer for Hijac's agent, solving the classic "AI amnesia" problem. It acts as a unified state system that captures user habits over time without requiring fragile workarounds.
**Integration tasks:**
* Set up Backboard.ai and connect it to the Jac Lang agent via its API.
* Utilize Backboard's **Memory Engine** to automatically extract and persist facts (like typical commute times or locations).
* On each significant sensor event, use Backboard.ai's **State Manager** to maintain conversational and behavioral context: *"User left office coordinates at 17:08."*
* Before taking action, the agent retrieves grounded historical context from Backboard.ai to check: *"Have I seen this pattern before? How many times?"*
* If pattern confidence > threshold → agent acts autonomously; otherwise, it suggests and asks.

**Why it fits:** Backboard.ai is the "long-term brain" of Hijac. Without a stateful memory layer, the agent would be stateless and dumb—it would never learn that you always go home at 5 PM. Backboard.ai is what transforms Hijac from a simple automation tool into an agent that genuinely learns your life across multiple sessions.

## 7. Implementation Tasks
*(Tasks are organized by priority. Complete them in order for the demo.)*

### PHASE 1 — Mobile Foundation (Priority: CRITICAL)
**Task 1.1 — Scaffold the Capacitor project**
* Create a new web app project (React or Vite).
* Install Capacitor: `npm install @capacitor/core @capacitor/cli`
* Initialize Capacitor: `npx cap init Hijac com.Hijac.app`
* Add Android platform: `npx cap add android`
* Configure `capacitor.config.ts` with correct `webDir`.
* Verify: `npx cap sync android` runs without errors.

**Task 1.2 — Install sensor plugins**
* Install Geolocation, Motion, and Device plugins.
* Add required Android permissions to `AndroidManifest.xml` (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `HIGH_SAMPLING_RATE_SENSORS`).
* Test: log GPS coordinates to console on a real device.

**Task 1.3 — Build sensor manager module**
* Create `src/sensors/SensorManager.ts`.
* Implement `startGeolocation(callback)` and `startMotion(callback)`.
* Implement `getContext()` (time, dayOfWeek, batteryLevel, networkType).
* Normalize all sensor values into a standard `SensorEvent` object.
* Implement debouncing so rapid sensor changes don't spam the agent.

**Task 1.4 — Run Jac Lang client in Capacitor web view**
* Install the Jac Lang JS client SDK.
* Initialize the Jac client in `src/agent/JacClient.ts`.
* Test: send a hardcoded message to the Jac agent and receive a response.

### PHASE 2 — Backend Setup (Priority: CRITICAL)
**Task 2.1 — Set up InsForge**
* Clone InsForge and configure `.env`.
* Run: `docker compose -f docker-compose.prod.yml up`
* Create the required tables (`sensor_events`, `user_rules`, `action_log`, `user_patterns`) via CLI.

**Task 2.2 — InsForge auth + user session**
* Set up InsForge auth.
* On app launch, silently create/retrieve a device-based user session.
* Store the session token using Capacitor's `@capacitor/preferences` plugin.

**Task 2.3 — InsForge edge function: evaluate_rules**
* Create an InsForge edge function that accepts a `SensorEvent` payload, queries `user_rules`, evaluates conditions, and returns a list of triggered actions.

**Task 2.4 — Connect Jac Lang agent to InsForge**
* Define InsForge tool functions the Jac agent can call (`insforge_log_event`, `insforge_get_history`, `insforge_log_action`, `insforge_get_user_rules`).

### PHASE 3 — Agent Integration (Priority: HIGH)
**Task 3.1 — Define the Jac Lang agent**
* Write the agent system prompt (see Appendix A).
* Define the agent's available tools.
* Define the agent's decision loop.

**Task 3.2 — Wire sensors to the agent**
* In `SensorManager`, on each significant event, call `JacClient.sendEvent(sensorEvent)`.
* Implement a throttle (e.g., 30 seconds max invocation rate).

**Task 3.3 — Set up Backboard.ai**
* Create a Backboard.ai account and install the SDK.
* Create `src/agent/BackboardClient.ts`.
* Implement `writeObservation()`, `readContext()`, and `updateConfidence()` using Backboard.ai's API.

**Task 3.4 — Agent memory loop**
* Before reasoning, call `BackboardClient.readContext()` and inject state into the context.
* After events, call `BackboardClient.writeObservation()`.
* After success, call `BackboardClient.updateConfidence()`.

### PHASE 4 — Action Execution (Priority: HIGH)
**Task 4.1 — Action: Open Google Maps to home**
* Implement `actions/openMapsHome.ts` utilizing deep links.

**Task 4.2 — Action: Send local push notification**
* Install `@capacitor/local-notifications` and implement handler.

**Task 4.3 — Action: Generic webhook**
* Implement `actions/sendWebhook.ts(url, payload)`.

**Task 4.4 — Action dispatcher**
* Create `ActionDispatcher.ts` to route triggers to the correct handlers. After action, log via InsForge and update Backboard.ai confidence.

### PHASE 5 — UI (Priority: MEDIUM)
* **Task 5.1:** Sensor dashboard (live display for demo).
* **Task 5.2:** Rules manager (enable/disable toggles).
* **Task 5.3:** Action history feed.
* **Task 5.4:** Agent chat interface (Stretch goal).

### PHASE 6 — Demo Polish (Priority: MEDIUM)
* **Task 6.1:** Rehearse the exact demo flow.
* **Task 6.2:** Build and deploy APK to the Samsung Galaxy S23.
* **Task 6.3:** Fallback demo mode ("Simulate Sensor" button to fake a GPS event if location services drop).

## 8. Appendix A — Jac Lang Agent System Prompt (Draft)

```text
You are Hijac, a mobile AI agent that monitors sensor data from the user's 
phone and takes actions on their behalf to optimize their daily routine.

You have access to the following tools:
- insforge_get_history: Read recent sensor events from the user's history
- insforge_log_event: Save a sensor event to the database
- insforge_log_action: Record when you take an action and what happened
- backboard_read_context: Read persistent state and recent observations
- backboard_write_observation: Send a new observation to the Memory Engine
- backboard_update_confidence: Increase or decrease pattern confidence
- action_open_maps: Open Google Maps to a destination
- action_send_notification: Send a push notification to the user
- action_send_webhook: Send a webhook to an external URL

When you receive a sensor event:
1. Read Backboard.ai context to understand the user's routine patterns.
2. Determine if this event matches a known pattern with high confidence (>0.7).
3. If yes and auto-mode is on, take the action autonomously and log it.
4. If yes but confidence is lower, send a notification asking the user.
5. If no known pattern, write a new observation to Backboard.ai.
6. Always log the sensor event to InsForge.

Be proactive but not annoying. Only surface actions that genuinely help.
```

## 9. Appendix B — Demo Rule Seed Data (InsForge)
*Seed these rules into InsForge for the demo:*

```json
[
  {
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
  },
  {
    "name": "Gym arrived notification",
    "condition": {
      "sensor_type": "geolocation",
      "near_location": { "lat": "GYM_LAT", "lng": "GYM_LNG", "radius_m": 100 }
    },
    "action_type": "send_notification",
    "action_params": { "title": "Hijac", "body": "Workout starting — logging it!" },
    "enabled": true
  }
]
```

## 10. Open Questions / Risks

| Risk | Mitigation |
| :--- | :--- |
| Jac Lang client may not support web/Capacitor out of the box. | Test this first (Task 1.4); if blocked, wrap API calls via InsForge edge function as proxy. |
| Capacitor Geolocation may require background permissions on Android 12+. | Request `ACCESS_BACKGROUND_LOCATION` in manifest; handle the permission dialog in-app. |
| Backboard.ai API access during hackathon. | Implement a local fallback: store patterns in InsForge `user_patterns` table and read from there. |
| Samsung Galaxy S23 APK sideloading requires USB debugging enabled. | Enable developer mode + USB debugging before the hackathon starts. |
| Demo location might not trigger real GPS rules. | Implement the "Simulate Sensor" button (Task 6.3) as a mandatory fallback. | jachacks
