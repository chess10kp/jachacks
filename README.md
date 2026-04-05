# Hijac — Product Requirements Document

## 1. Overview
Hijac is a mobile-first application that Hijacs your daily routine to do things for you. It reads sensor data from your phone in real time—location, gyroscope, accelerometer, time, and more—and uses an AI agent or user-defined automation rules to perform tasks on your behalf without you having to think about it.

Hijac is built entirely in **Jac**—an AI-native programming language. The application uses Jac's custom `hj` (Hijac) codespace to compile to JavaScript, which is automatically wrapped with Capacitor as a Progressive Web App (PWA) for access to native device sensors on Android (Samsung Galaxy S23+). All agent logic (walkers, nodes) runs on-device, with InsForge and **Backboard.ai** called via API for persistence and memory.

## 2. Goals
* Deliver a working demo that reads at least two sensor inputs (location + one analog sensor) and triggers a real action.
* Write the entire application in Jac language using the `hj` codespace (compiles to JS + Capacitor for mobile).
* Integrate InsForge API for database, auth, and persistence (called directly from mobile app).
* Integrate **Backboard.ai** API for persistent agent memory (called directly from mobile app).
* Win sponsor tracks for Jac Lang, InsForge, and Backboard.ai.

## 3. Tech Stack

| Layer | Technology |
| :--- | :--- |
| **Primary Language** | Jac (AI-native full-stack language) |
| **Mobile Compilation** | Jac `hj { }` codespace → JavaScript → Capacitor → Android PWA |
| **Sensor APIs** | Capacitor plugins: Geolocation, Motion, Device |
| **App Logic** | Jac walkers + nodes (all runs on-device) |
| **Backend Infra** | InsForge (DB, auth, storage, edge functions - called via API) |
| **Agent Memory** | Backboard.ai (called via API) |
| **Target Device** | Samsung Galaxy S23 (Android) |

### The `hj` Codespace (Mobile Target)
The `hj` codespace is a custom compilation target for mobile-first apps:

```
hj { }
   ↓
JavaScript (PWA bundle)
   ↓
Capacitor (automatic wrapper)
   ↓
Android/iOS Native App
```

**What `hj` provides:**
- Automatic Capacitor integration (no manual setup)
- Pre-configured sensor plugin imports (Geolocation, Motion, Device)
- Native permission handling for Android/iOS
- Direct access to Capacitor APIs from Jac code
- Single build command: `jac build --target mobile app.jac`

**All logic runs on-device** - walkers traverse nodes locally, API calls to InsForge/Backboard go directly from the mobile app.

## 4. Architecture

```text
[Sensor Layer]        [App Layer - All On-Device]           [External APIs]
   Geolocation      →                                    →   Backboard.ai
   Gyroscope        →   Jac hj { } compiled to JS         →   (Memory)
   Accelerometer    →   + Capacitor                        →
   Time/Calendar    →       ↓                              →   InsForge
                          ↓                                →   (DB + Auth)
                     Nodes + Walkers                       →
                     (state + agent logic)
                          ↓
                   [Action Execution]
                   Maps, Notifications, Webhooks
```

**Data Flow:**
1.  Capacitor plugins poll or subscribe to sensor events.
2.  Sensor data creates/updates nodes in the Jac object graph (on-device).
3.  Jac walkers traverse the graph to analyze sensor state and patterns.
4.  Walkers call Backboard.ai API for historical context via `by llm()` constructs.
5.  Walkers evaluate user-defined rules + AI reasoning to decide whether to trigger an action.
6.  Actions are executed (deep links, API calls, notifications).
7.  Results are logged to the Jac graph (auto-persisted locally) and synced to InsForge API.

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

### Feature 3 — AI Agent (Jac Walker)
An AI agent that goes beyond static rules. The agent is implemented as a **Jac walker** that traverses a graph of sensor nodes, observes patterns over time (via Backboard.ai memory), infers context, and proactively takes actions or makes suggestions.

**Jac Object-Spatial Programming Model:**
* **Nodes:** Represent sensor states (LocationNode, MotionNode, TimeNode), user contexts, and action targets
* **Edges:** Connect related states (e.g., LocationNode --at_time--> TimeNode)
* **Walkers:** The agent that traverses nodes, making decisions based on the graph structure
* **`by llm()`:** Jac's native AI construct—replaces manual prompt engineering with type-safe LLM calls

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
Jac is an AI-native full-stack programming language with built-in agentic constructs. Unlike traditional frameworks, Jac incorporates agents (walkers), graph-based state (nodes/edges), and LLM integration (`by llm()`) directly into the language grammar.

**Integration tasks:**
* Install Jac: `pip install jaseci` and set up the development environment.
* Create a Jac project with the `hj` codespace: `jac create --use hijac hijac` (enables mobile compilation).
* Define sensor nodes: `node LocationNode`, `node MotionNode`, `node TimeNode` with `has` data fields.
* Define the agent walker: `walker HijacAgent` that traverses sensor nodes and decides actions.
* Use `by llm()` for AI reasoning instead of manual prompt engineering—Jac auto-generates prompts from type signatures.
* Wire Capacitor sensor events to update Jac node states in the graph.
* Implement action handlers as node abilities: `can open_maps`, `can send_notification`, etc.
* Build mobile app: `jac build --target mobile app.jac` (compiles `hj` blocks and wraps with Capacitor).

**Why it fits:** Jac is the brain of Hijac. The hackathon is sponsored by Jac, and Hijac is built ground-up on the language itself. This demonstrates Jac's ability to build mobile-first AI apps with walkers, nodes, and `by llm()` - all running on-device.

### 6B — InsForge (Backend for Agentic Development)
InsForge is a backend platform built for AI agents. It exposes databases, auth, storage, and edge functions through a semantic layer that agents can understand and operate directly. Think of it as "Supabase but the agent drives."

**Integration tasks:**
* Set up an InsForge project (cloud).
* Create tables: `sensor_events`, `user_rules`, `action_log`, `user_patterns` via InsForge CLI.
* In `hj { }` blocks, call InsForge API directly from the mobile app:
  ```jac
  hj {
      def log_sensor_event(event: dict) -> void {
          fetch("https://insforge.api/sensor_events", {
              method: "POST",
              body: event
          });
      }
  }
  ```
* Auth: use InsForge auth to identify the user's device session.
* Let walkers query InsForge for historical data and user rules.

**Why it fits:** InsForge was built for AI agents that need persistent storage. The Jac walker on the mobile device calls InsForge APIs directly - demonstrating agent-driven backend operations.

### 6C — Backboard.ai (Persistent Memory Layer)
Backboard.ai serves as the persistent memory layer for Hijac's agent, solving the classic "AI amnesia" problem. It acts as a unified state system that captures user habits over time without requiring fragile workarounds.

**Integration tasks:**
* Set up Backboard.ai account and get API key.
* In `hj { }` blocks, create API wrapper functions:
  ```jac
  hj {
      def write_observation(assistant_id: str, user_id: str, namespace: str, observation: str) -> void {
          fetch(f"https://app.backboard.io/api/assistants/{assistant_id}/memories", {
              method: "POST",
              headers: {
                  "X-API-Key": BACKBOARD_KEY,
                  "Content-Type": "application/json"
              },
              body: {
                  content: f"[{namespace}] {observation}",
                  metadata: {namespace, user_id}
              }
          });
      }

      def read_context(assistant_id: str, user_id: str, query: str) -> dict {
          resp = fetch(f"https://app.backboard.io/api/assistants/{assistant_id}/memories/search", {
              method: "POST",
              headers: {
                  "X-API-Key": BACKBOARD_KEY,
                  "Content-Type": "application/json"
              },
              body: {query: f"user:{user_id} {query}", limit: 5}
          });
          return resp.json();
      }
  }
  ```
* Utilize Backboard's **Memory Engine** to automatically extract and persist facts.
* For cross-thread memory extraction/retrieval during inference, call `POST /threads/{thread_id}/messages` with `memory: "Auto"` (or `"Readonly"` for read-only recall).
* Before taking action, walkers retrieve historical context from Backboard.ai.
* If pattern confidence > threshold → walker acts autonomously; otherwise, suggests and asks.

**Why it fits:** Backboard.ai is the "long-term brain" of Hijac. The Jac walker calls Backboard.ai API to store and retrieve patterns - transforming Hijac from a simple automation tool into an agent that learns your life across multiple sessions.

## 7. Implementation Tasks
*(Tasks are organized by priority. Complete them in order for the demo.)*

### PHASE 1 — Jac Foundation & Mobile Setup (Priority: CRITICAL)
**Task 1.1 — Install and configure Jac**
* Install Jaseci stack: `pip install jaseci`
* Verify installation: `jac --version`
* Install VS Code extension for Jac language support (optional but recommended).

**Task 1.2 — Scaffold the Jac project**
* Create project with `hj` codespace: `jac create --use hijac hijac`
* This creates a Jac project configured for mobile compilation.
* Project structure includes `.jac` files with all logic in `hj` blocks.

**Task 1.3 — Define sensor nodes in Jac**
* Create `nodes.jac` with node definitions:
  ```jac
  node LocationNode {
      has lat: float;
      has lng: float;
      has accuracy: float;
      has timestamp: int;
  }
  
  node MotionNode {
      has accel_x: float;
      has accel_y: float;
      has accel_z: float;
      has gyro_x: float;
      has gyro_y: float;
      has gyro_z: float;
  }
  
  node TimeNode {
      has day_of_week: str;
      has hour: int;
      has minute: int;
  }
  ```
* Connect nodes to `root` for automatic persistence.

**Task 1.4 — Build with `hj` codespace**
* The `hj` codespace automatically handles Capacitor integration.
* Build command: `jac build --target mobile app.jac`
* This compiles `hj { }` blocks to JavaScript and wraps with Capacitor.
* Output includes Android project in `android/` directory ready for APK build.

**Task 1.5 — Configure sensor permissions**
* The `hj` codespace auto-configures Capacitor plugins (Geolocation, Motion, Device).
* Add required Android permissions to `AndroidManifest.xml`:
  * `ACCESS_FINE_LOCATION`
  * `ACCESS_COARSE_LOCATION`
  * `HIGH_SAMPLING_RATE_SENSORS`
  * `ACCESS_BACKGROUND_LOCATION` (for Android 12+)

**Task 1.6 — Bridge sensors to Jac nodes in `hj` blocks**
* In Jac `hj { }` blocks, use pre-configured Capacitor plugin imports:
  ```jac
  hj {
      def update_location_node(node: LocationNode) -> void {
          pos = Geolocation.getCurrentPosition();
          node.lat = pos.coords.latitude;
          node.lng = pos.coords.longitude;
          node.accuracy = pos.coords.accuracy;
      }
  }
  ```
* Implement debouncing to prevent rapid updates.

### PHASE 2 — InsForge & Backboard API Setup (Priority: CRITICAL)
**Task 2.1 — Set up InsForge**
* Create InsForge cloud project.
* Create tables via CLI: `sensor_events`, `user_rules`, `action_log`, `user_patterns`.
* Get API credentials (endpoint URL, API key).

**Task 2.2 — Set up Backboard.ai**
* Create Backboard.ai account.
* Get API key for Memory Engine access.

**Task 2.3 — Create API wrapper functions in `hj`**
* In `hj { }` blocks, create functions to call InsForge and Backboard:
  ```jac
  hj {
      # InsForge
      def insforge_insert(table: str, data: dict) -> void { ... }
      def insforge_query(table: str, filters: dict) -> list { ... }
      
      # Backboard
      def backboard_write(assistant_id: str, user_id: str, namespace: str, obs: str) -> void { ... }
      def backboard_read(assistant_id: str, user_id: str, query: str) -> dict { ... }
  }
  ```

**Task 2.4 — InsForge auth + user session**
* Implement InsForge auth flow in `hj` blocks.
* Store session token using `hj` built-in storage (Capacitor Preferences).
* Attach auth headers to all API calls.

### PHASE 3 — Jac Walker Agent Implementation (Priority: HIGH)
**Task 3.1 — Define the Jac walker (agent)**
* Create `agent.jac` with the HijacAgent walker:
  ```jac
  walker HijacAgent {
      has auto_mode: bool = false;
      has confidence_threshold: float = 0.7;
      
      # Entry point: start at root
      can start with Root entry {
          visit [-->];  # Traverse all connected nodes
      }
      
      # When visiting a LocationNode
      can analyze_location with LocationNode entry {
          # Get context from Backboard.ai
          context = backboard_read(assistant_id, user_id, "ritual_patterns geofence_patterns conversation_commitments");
          
          # Use by llm() for AI reasoning
          decision = by llm() -> str {
              "Should I trigger an action based on this location?"
          };
          if decision == "yes" {
              take_action(here);
          }
          visit [-->];
      }
  }
  ```

**Task 3.2 — Wire sensors to walker traversal**
* On each significant sensor event, spawn the walker:
  ```jac
  root spawn HijacAgent(auto_mode=True);
  ```
* Implement throttling (e.g., max one spawn per 30 seconds).

**Task 3.3 — Implement `by llm()` reasoning**
* Use Jac's `by llm()` construct for type-safe AI calls:
  ```jac
  def should_trigger_action(location: LocationNode, time: TimeNode) -> bool by llm() {
      # Jac auto-generates prompt from function signature
      # and parses response to return bool
  }
  ```

**Task 3.4 — Agent memory loop**
* Before reasoning, walkers call `backboard_read(assistant_id, user_id, query)` to get historical patterns.
* After events, walkers call `backboard_write(assistant_id, user_id, namespace, obs)` to record new patterns.
* For agent turn memory extraction and retrieval, call `POST /threads/{thread_id}/messages` with `memory: "Auto"` (or `"Readonly"` for retrieval-only).
* Use `by llm()` to evaluate confidence based on Backboard.ai context.
* Log all events to InsForge via `insforge_insert()`.

### PHASE 4 — Action Execution as Node Abilities (Priority: HIGH)
**Task 4.1 — Define action abilities on nodes**
* Add action methods to nodes using `can`:
  ```jac
  node ActionNode {
      can open_maps(destination: str) -> void {
          # Use Capacitor to open deep link
          link = f"geo:0,0?q={destination}";
          window.open(link);
      }
      
      can send_notification(title: str, body: str) -> void {
          # Use Capacitor LocalNotifications
          LocalNotifications.schedule({notifications: [{title, body}]});
      }
  }
  ```

**Task 4.2 — Action: Open Google Maps to home**
* Implement `can open_maps_home` on ActionNode.
* Use Capacitor's App plugin to open deep links.

**Task 4.3 — Action: Send local push notification**
* The `hj` codespace includes pre-configured `@capacitor/local-notifications`.
* Use directly in `hj { }` blocks.
* Implement notification scheduling.

**Task 4.4 — Action: Generic webhook**
* Implement `can send_webhook(url: str, payload: dict)` using fetch API.
* Callable from `hj` mobile code.

**Task 4.5 — Walker action dispatcher**
* Walkers call node abilities directly when traversing:
  ```jac
  walker HijacAgent {
      can execute_actions with ActionNode entry {
          if here.should_trigger {
              here.open_maps("home");
              log_action(here);  # Log to InsForge
          }
      }
  }
  ```
* After action, log via InsForge (call server function) and update Backboard.ai.

### PHASE 5 — UI in Jac Mobile Code (Priority: MEDIUM)
* **Task 5.1:** Sensor dashboard in `hj { }` blocks using React-like syntax (live display for demo).
* **Task 5.2:** Rules manager UI (enable/disable toggles) with Jac state management.
* **Task 5.3:** Action history feed displaying data from InsForge.
* **Task 5.4:** Agent chat interface (Stretch goal)—can use `by llm()` for conversational responses.

### PHASE 6 — Demo Polish & Deployment (Priority: MEDIUM)
* **Task 6.1:** Compile Jac to JavaScript: `jac build app.jac` (generates JS bundle).
* **Task 6.2:** Sync with Capacitor: `npx cap sync android`.
* **Task 6.3:** Build APK: Open Android Studio from `android/` folder and build signed APK.
* **Task 6.4:** Deploy APK to Samsung Galaxy S23 via USB debugging.
* **Task 6.5:** Rehearse exact demo flow with live sensor triggers.
* **Task 6.6:** Implement "Simulate Sensor" fallback button in UI (fake GPS event if location services drop).
* **Task 6.7:** Primary pitch demo should be **Tabletop Ritual Agent**: set phone down -> agent enters focus conversation mode -> pick phone up -> agent executes wrap-up actions.

#### PHASE 6A — Tabletop Ritual Sensor Detection Requirements
* Capture motion + orientation samples at `2 Hz` for demo stability:
  * `accel_x`, `accel_y`, `accel_z`
  * `gyro_x`, `gyro_y`, `gyro_z`
  * `orientation_alpha`, `orientation_beta`, `orientation_gamma`
  * `timestamp`, `device_orientation`, `screen_state` (if available)
* Derive real-time metrics in `hj { }` before sending to the walker:
  * `accel_norm = sqrt(ax^2 + ay^2 + az^2)`
  * `gyro_norm = sqrt(gx^2 + gy^2 + gz^2)`
  * `is_flat = abs(accel_norm - 9.81) < 0.7`
  * `is_face_down = accel_z < -7.5` (calibrate once on-device)
* Episode detector: **phone set down** (`face_down_stationary`):
  * Require `is_flat == true`, `is_face_down == true`, and `gyro_norm < 0.08`
  * Hold for `>= 8 seconds` (at least 16 consecutive samples at 2 Hz)
  * Emit one episode event with confidence and sample window IDs
* Episode detector: **phone picked up** (`pickup_transition`):
  * Valid only when `focus_mode_active == true`
  * Trigger when `gyro_norm > 0.35` or `abs(delta(accel_norm)) > 1.2` for 2+ consecutive samples
  * Confirm orientation is no longer flat within 2 seconds (`abs(accel_z) < 6.5`)
* Episode detector: **left building geofence** (`geofence_exit`) for location-enabled demo:
  * Poll location every `10-15 sec`, only keep samples with `accuracy_m <= 40`
  * Define building center (`lat`, `lng`) and radius `R` (start with `R = 120m`)
  * Exit rule: `distance_from_center > R + max(accuracy_m, 20)` for 2 consecutive samples
  * Anti-flap hysteresis: re-enter only when `distance_from_center <= R - 15`

#### PHASE 6B — Backend Setup Requirements (InsForge + Backboard.ai)
* Keep all raw telemetry and deterministic episodes in InsForge; keep cross-session habit memory in Backboard.ai.
* Required InsForge tables for demo backend:
  * `sensor_events`: raw sensor rows + derived flags
  * `episode_log`: normalized episode records (`face_down_stationary`, `pickup_transition`, `geofence_exit`)
  * `action_log`: all suggested/executed actions + result status
  * `user_patterns`: compact scorecard (`accept_rate`, `last_seen`, `confidence`)
  * `conversation_notes`: optional text/transcript snippets captured during focus mode
  * `user_integrations`: encrypted tokens/webhook configs for external automations
* Recommended fields:
  * `sensor_events`: `id`, `user_id`, `sensor_type`, `payload_json`, `derived_json`, `ts`
  * `episode_log`: `id`, `user_id`, `episode_type`, `start_ts`, `end_ts`, `confidence`, `context_json`
  * `action_log`: `id`, `user_id`, `episode_id`, `action_type`, `action_payload`, `status`, `result_json`, `ts`
  * `conversation_notes`: `id`, `user_id`, `episode_id`, `text`, `entities_json`, `ts`
* Required indexes:
  * `sensor_events(user_id, ts)`
  * `episode_log(user_id, end_ts)`
  * `action_log(user_id, ts)`
  * `conversation_notes(user_id, ts)`
* Backboard.ai memory design (agent "long-term brain"):
  * Namespace `ritual_patterns`: learned confidence for set-down -> pickup ritual
  * Namespace `geofence_patterns`: office exit patterns by weekday/time
  * Namespace `conversation_commitments`: extracted "follow-up promises" and outcomes
* Backboard.ai write policy:
  * Write after each episode completion with action outcome
  * Write acceptance/rejection feedback after every suggestion
  * Write compact summary at end of focus mode (`what happened`, `what user accepted`)
* Backboard.ai read policy:
  * Read before decision step (`runCycle`) to pull recent pattern summaries
  * Read before external action execution to personalize defaults (home route, preferred reminder time, preferred food link)

#### PHASE 6C — Agent Decision and Action Requirements
* Implement one backend decision loop in the walker/agent class:
  * `collect current episode + context`
  * `fetch Backboard memory + InsForge recent history`
  * `compute confidence`
  * `if confidence >= threshold and auto_mode -> execute action`
  * `else -> suggest action and wait for user response`
  * `persist outcome to InsForge + Backboard`
* Keep confidence transparent in demo UI:
  * show `confidence_score`
  * show `top memory reasons` used in the decision
  * show whether decision came from `rule`, `memory`, or `both`

#### PHASE 6D — Easy and Feasible Automations for Demo
* **Easy (recommended): Google Calendar follow-up event**
  * Trigger: `pickup_transition` ends focus conversation mode
  * Input: optional `conversation_notes.text`
  * Agent step: extract task/time with `by llm()` and create event draft payload
  * Backend step: call InsForge edge function `create_calendar_event`
  * Log event ID and status in `action_log`
* **Easy fallback: Todoist task + Slack/Discord webhook summary**
  * Trigger: same as above
  * Action: create "next action" task and post summary to team channel
* **Geofence mundane automation (feasible in hackathon): leave building -> lunch reorder prompt**
  * Trigger: `geofence_exit` between `11:30-13:30`
  * Action: call simple webhook (`Pipedream`/`Zapier`/custom endpoint) that returns a one-tap deep link to preferred food app/cart
  * UX: send local notification, user confirms with one tap, then open deep link
  * Note: avoid direct card-charging APIs in demo; use confirm-and-open flow for reliability

#### PHASE 6E — Winning Pitch Runbook (2 minutes)
* Step 1: Place phone face-down for 8-10 sec. Show detected `face_down_stationary`.
* Step 2: Agent enters focus mode and starts memory-backed observation.
* Step 3: Add one short conversation note ("Need follow-up with Alex tomorrow at 10").
* Step 4: Pick up phone. Show detected `pickup_transition`.
* Step 5: Agent proposes (or auto-runs) Google Calendar follow-up event.
* Step 6: Show live InsForge rows (`episode_log`, `action_log`) and Backboard memory summary update.
* Step 7: Optional second flow: trigger geofence exit simulation and show lunch reorder prompt.
* Step 8: End with confidence increase across repetitions ("learns from your routine").

## 8. Appendix A — Jac Walker Agent Example

```jac
# hijac_agent.jac - Core agent implementation (all runs on-device)

# Define the sensor nodes
node LocationNode {
    has lat: float;
    has lng: float;
    has accuracy: float;
    has timestamp: int;
    
    can is_near(target_lat: float, target_lng: float, radius_m: float) -> bool {
        distance = calculate_distance(here.lat, here.lng, target_lat, target_lng);
        return distance <= radius_m;
    }
}

node TimeNode {
    has day: str;
    has hour: int;
    has minute: int;
    
    can is_workday() -> bool {
        return here.day in ["MON", "TUE", "WED", "THU", "FRI"];
    }
    
    can is_after(hour_threshold: int) -> bool {
        return here.hour >= hour_threshold;
    }
}

# Mobile app code (compiles to JS + Capacitor)
hj {
    # API wrappers - call external services directly
    def read_context(assistant_id: str, user_id: str, query: str) -> dict {
        resp = fetch(f"https://app.backboard.io/api/assistants/{assistant_id}/memories/search", {
            method: "POST",
            headers: {
                "X-API-Key": BACKBOARD_KEY,
                "Content-Type": "application/json"
            },
            body: {query: f"user:{user_id} {query}", limit: 5}
        });
        return resp.json();
    }

    def write_observation(assistant_id: str, user_id: str, namespace: str, obs: str) -> void {
        fetch(f"https://app.backboard.io/api/assistants/{assistant_id}/memories", {
            method: "POST",
            headers: {
                "X-API-Key": BACKBOARD_KEY,
                "Content-Type": "application/json"
            },
            body: {
                content: f"[{namespace}] {obs}",
                metadata: {namespace, user_id}
            }
        });

        # Also log to InsForge
        insforge_insert('sensor_events', {user_id, observation: obs});
    }
    
    def log_action(user_id: str, action: str, result: str) -> void {
        insforge_insert('action_log', {
            user_id, action, result, timestamp: Date.now()
        });
    }
    
    def insforge_insert(table: str, data: dict) -> void {
        fetch(f"https://api.insforge.io/{table}", {
            method: "POST",
            headers: {
                "Authorization": f"Bearer {INSFORGE_KEY}",
                "Content-Type": "application/json"
            },
            body: data
        });
    }
    
    # Action handlers using Capacitor
    def take_action(node: LocationNode) -> void {
        if node.is_near(OFFICE_LAT, OFFICE_LNG, 200) {
            # Open Google Maps to home
            window.open(f"geo:0,0?q=Home");
            log_action(user_id, "open_maps", "success");
        }
    }
    
    def suggest_action(node: LocationNode) -> void {
        LocalNotifications.schedule({
            notifications: [{
                title: "Hijac",
                body: "Want me to open Maps to home?",
                id: 1
            }]
        });
    }
}

# Define the agent walker
walker HijacAgent {
    has auto_mode: bool = false;
    has confidence_threshold: float = 0.7;
    
    # Entry point
    can start with Root entry {
        visit [-->];
    }
    
    # Analyze location context
    can analyze with LocationNode entry {
        # Get historical context from Backboard.ai
        context = read_context(assistant_id, user_id, "ritual_patterns geofence_patterns conversation_commitments");
        
        # Use by llm() for AI reasoning
        should_act: bool = by llm(
            location=here,
            history=context,
            auto_mode=auto_mode
        ) -> bool {
            "Based on the user's location history and current context,
             should I trigger an automated action?"
        };
        
        if should_act and auto_mode {
            take_action(here);
        } else if should_act {
            suggest_action(here);
        }
        
        # Record observation
        write_observation(assistant_id, user_id, "ritual_patterns", f"User at {here.lat}, {here.lng}");
        
        visit [-->];
    }
}

# Main entry point
with entry {
    # Initialize graph
    loc = LocationNode(lat=0.0, lng=0.0, accuracy=0.0, timestamp=0);
    time = TimeNode(day="MON", hour=17, minute=0);
    
    # Connect to root for persistence
    root ++> loc;
    root ++> time;
    
    # Spawn agent
    root spawn HijacAgent(auto_mode=True);
}
```

**Key Jac Features Demonstrated:**
* **Nodes:** `LocationNode` and `TimeNode` represent sensor state
* **Walkers:** `HijacAgent` traverses nodes and makes decisions
* **`by llm()`:** AI reasoning without manual prompt engineering
* **`hj` codespace:** All code compiles to JS + Capacitor for mobile
* **Automatic persistence:** Nodes connected to `root` are auto-saved locally
* **Direct API calls:** Call InsForge/Backboard directly from mobile app - no server needed

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
| Jac `hj` codespace is custom - may need implementation work. | Test early; have fallback to vanilla JS + Capacitor if needed. |
| Jac is a newer language—may encounter compiler bugs or missing features. | Have fallback plan: write critical path in vanilla JS if Jac compilation fails. |
| Capacitor Geolocation requires background permissions on Android 12+. | Request `ACCESS_BACKGROUND_LOCATION` in manifest; handle permission dialog in-app. |
| Backboard.ai API access during hackathon. | Implement local fallback: store patterns in Jac's auto-persisted nodes + InsForge. |
| Samsung Galaxy S23 APK sideloading requires USB debugging enabled. | Enable developer mode + USB debugging before the hackathon starts. |
| Demo location might not trigger real GPS rules. | Implement "Simulate Sensor" button (Task 6.6) as mandatory fallback. |
| API calls from mobile may have CORS issues. | InsForge/Backboard should support CORS; test API calls early. | jachacks
