# Docstring removed

cl import from react { useState, useEffect, useRef }
cl import from "@capacitor/motion" { Motion }
cl import from "@capgo/capacitor-barometer" { CapacitorBarometer }
cl import from "@capgo/capacitor-compass" { CapgoCompass }
cl import from "@capacitor/device" { Device }
cl import from "@capacitor/geolocation" { Geolocation }
cl import from "@capacitor/camera" { Camera, CameraResultType }
cl import from "@mozartec/capacitor-microphone" { Microphone }
cl import from "@capacitor/haptics" { Haptics, ImpactStyle }

node MotionSnapshot {
    has accel_x: float = 0.0;
    has accel_y: float = 0.0;
    has accel_z: float = 0.0;
    has gyro_alpha: float = 0.0;
    has gyro_beta: float = 0.0;
    has gyro_gamma: float = 0.0;
    has timestamp: int = 0;

    def intensity -> float {
        return (self.accel_x * self.accel_x
            + self.accel_y * self.accel_y
            + self.accel_z * self.accel_z) ** 0.5;
    }
}

obj MotionDecision {
    has action_type: str = "log";
    has message: str = "No motion data";
    has priority: int = 0;
    has source: str = "rule";
}

def infer_motion_decision(
    snapshot: MotionSnapshot,
    motion_threshold: float,
    auto_act: bool
) -> MotionDecision by llm();

walker MotionDecisionWalker {
    has motion_data: dict;
    has motion_threshold: float = 2.5;
    has auto_act: bool = True;
    has use_llm: bool = False;

    can evaluate with Root entry {
        accel = self.motion_data.acceleration if self.motion_data else None;
        gyro = self.motion_data.rotationRate if self.motion_data else None;

        snapshot = MotionSnapshot(
            accel_x=(accel.x if accel and accel.x else 0.0),
            accel_y=(accel.y if accel and accel.y else 0.0),
            accel_z=(accel.z if accel and accel.z else 0.0),
            gyro_alpha=(gyro.alpha if gyro and gyro.alpha else 0.0),
            gyro_beta=(gyro.beta if gyro and gyro.beta else 0.0),
            gyro_gamma=(gyro.gamma if gyro and gyro.gamma else 0.0),
            timestamp=(self.motion_data.timestamp if self.motion_data and self.motion_data.timestamp else 0)
        );

        intensity = snapshot.intensity();

        decision = MotionDecision(
            action_type=("trigger" if self.auto_act else "notify") if intensity > self.motion_threshold else "log",
            message=(
                "High motion detected: intensity " + str(round(intensity, 2))
                if intensity > self.motion_threshold
                else "Normal motion: intensity " + str(round(intensity, 2))
            ),
            priority=(2 if intensity > 10 else 1) if intensity > self.motion_threshold else 0,
            source="rule"
        );

        if self.use_llm {
            llm_decision = infer_motion_decision(snapshot, self.motion_threshold, self.auto_act);
            if llm_decision {
                llm_decision.source = "llm";
                decision = llm_decision;
            }
        }

        report {
            "type": decision.action_type,
            "message": decision.message,
            "priority": decision.priority,
            "source": decision.source
        };
    }
}

node EatingPredictionNode {
    has destination_name: str = "";
    has confidence_pct: int = 0;
    has reason: str = "";
    has source: str = "fallback";
    has day_of_week: str = "";
    has hour: int = 0;
}

walker PredictEatingDestinationWalker {
    has context: dict;

    can predict with Root entry {
        hour = int(self.context.hour if self.context and self.context.hour is not None else 12);
        day_of_week = self.context.day_of_week if self.context and self.context.day_of_week else "UNK";

        destination = self.context.fallback_destination if self.context and self.context.fallback_destination else "Nearby food spot";
        confidence = 38;
        reason = "Fallback prediction based on meal time and day";
        source = "time-day-fallback";

        memory_destination = self.context.memory_destination if self.context and self.context.memory_destination else "";
        memory_strength = Number(self.context.memory_strength if self.context and self.context.memory_strength is not None else 0);
        memory_hits = Number(self.context.memory_hits if self.context and self.context.memory_hits is not None else 0);

        if memory_destination and memory_strength > 0 {
            destination = memory_destination;
            confidence = 55 + int(Math.min(35, memory_strength * 14 + memory_hits * 3));
            reason = "Historical eating location patterns align with current time and day";
            source = "backboard+time-day";
        } elif memory_hits > 0 {
            confidence = confidence + 10;
            reason = "Light historical signal combined with current time and day";
            source = "light-memory+time-day";
        }

        if (day_of_week == "SAT" or day_of_week == "SUN") and source == "time-day-fallback" {
            confidence = confidence + 6;
            if hour >= 18 {
                destination = "Neighborhood Bistro";
            }
        }

        if confidence < 20 {
            confidence = 20;
        }
        if confidence > 95 {
            confidence = 95;
        }

        prediction = EatingPredictionNode(
            destination_name=destination,
            confidence_pct=confidence,
            reason=reason,
            source=source,
            day_of_week=day_of_week,
            hour=hour
        );

        report {
            "destination_name": prediction.destination_name,
            "confidence_pct": prediction.confidence_pct,
            "reason": prediction.reason,
            "source": prediction.source,
            "day_of_week": prediction.day_of_week,
            "hour": prediction.hour
        };
    }
}

cl {
    def insforge_base_url -> str {
        return "https://ww8eiidv.us-east.insforge.app";
    }

    def insforge_anon_key -> str {
        return "ik_90dd3cbd3d6b4e9620bb549a7156b840";
    }

    def backboard_base_url -> str {
        return "https://app.backboard.io/api";
    }

    def backboard_key -> str {
        return "espr_F4OSIbpFh9A1iTnxHLOus3kjTMl25h3Wk4awDuUZyuA";
    }

    def backboard_assistant_id -> str {
        return "67f63b37-0648-4e96-b084-1c4464bd350b";
    }

    def office_geofence -> dict {
        return {
            "name": "office",
            "lat": 37.774900,
            "lng": -122.419400,
            "radius_m": 120
        };
    }

    def emergency_contact -> str {
        return "+17344449383";
    }

    def emergency_contact_name -> str {
        return "Emergency Contact";
    }

    async def speak_text(text: str, voice_id: str = "") -> dict {
        if not text or text.trim().length == 0 {
            return {"ok": False, "reason": "empty_text"};
        }

        normalized = text.trim().toLowerCase();
        if normalized == "do you wnat to place your usual order?" {
            return {"ok": True, "audio_url": "/order.mp3"};
        }
        if normalized.indexOf("spicy chicken bowl") >= 0 {
            return {"ok": True, "audio_url": "/spicy-chicken-bowl.mp3"};
        }

        return {"ok": False, "reason": "local_asset_not_found"};
    }

    def fall_detection_thresholds -> dict {
        return {
            "impact_accel_norm": 15.0,  # m/s² (~1.5G) - phone drop creates 15-30 m/s²
            "stillness_gyro_norm": 0.5,  # rad/s - realistic for a still phone with sensor noise
            "stillness_duration_ms": 2000,  # 2 seconds of stillness after impact
            "orientation_change_deg": 45.0,  # degrees from upright - phone landed on side/face
            "confidence_threshold": 0.80,
            "countdown_seconds": 30
        };
    }

    def now_iso -> str {
        return Reflect.construct(Date, []).toISOString();
    }

    def to_num(value: Any, fallback: float = 0.0) -> float {
        num = Number(value);
        return fallback if Number.isNaN(num) else num;
    }

    def haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float {
        to_rad = lambda deg: float -> float {
            return deg * (Math.PI / 180.0);
        };
        d_lat = to_rad(lat2 - lat1);
        d_lng = to_rad(lng2 - lng1);
        a = (Math.sin(d_lat / 2.0) ** 2) + Math.cos(to_rad(lat1)) * Math.cos(to_rad(lat2)) * (Math.sin(d_lng / 2.0) ** 2);
        c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a));
        return 6371000.0 * c;
    }

    async def fetch_weather(lat: float, lng: float) -> dict {
        api_key = Reflect.get(window, "VITE_OPENWEATHERMAP_API_KEY") or "";
        if not api_key or api_key == "your-openweathermap-api-key-here" {
            print("Weather: No API key configured");
            return {"ok": False, "reason": "no_api_key"};
        }
        
        try {
            url = "https://api.openweathermap.org/data/2.5/weather?lat="
                + String(lat) + "&lon=" + String(lng)
                + "&appid=" + api_key + "&units=metric";
            
            res = await fetch(url);
            if not res.ok {
                return {"ok": False, "reason": "api_error"};
            }
            
            data = await res.json();
            return {
                "ok": True,
                "temp": data.main.temp,
                "feels_like": data.main.feels_like,
                "humidity": data.main.humidity,
                "description": data.weather[0].description if data.weather and data.weather[0] else "",
                "icon": data.weather[0].icon if data.weather and data.weather[0] else "",
                "wind_speed": data.wind.speed if data.wind else 0,
                "city": data.name or "Unknown"
            };
        } except Exception as e {
            print("Weather fetch error:", e);
            return {"ok": False, "reason": "network_error"};
        }
    }

    async def insforge_insert(table_name: str, row: dict) -> dict {
        base_url = insforge_base_url();
        anon_key = insforge_anon_key();

        if not base_url or not anon_key {
            return {"ok": False, "reason": "missing_insforge_env"};
        }

        try {
            res = await fetch(
                base_url + "/api/database/records/" + table_name,
                {
                    "method": "POST",
                    "headers": {
                        "Authorization": "Bearer " + anon_key,
                        "Content-Type": "application/json",
                        "Prefer": "return=representation"
                    },
                    "body": JSON.stringify([row])
                }
            );

            if not res.ok {
                body_text = await res.text();
                print("InsForge insert failed", table_name, res.status, body_text);
                return {"ok": False, "status": res.status};
            }

            data = await res.json().catch(lambda -> Any { return []; });
            return {
                "ok": True,
                "record": (data[0] if data and data.length and data[0] else None)
            };
        } except Exception as e {
            print("InsForge insert error", table_name, e);
            return {"ok": False, "reason": "network_error"};
        }
    }

    async def log_sensor_event(user_id: str, sensor_type: str, payload: dict, derived: dict) -> dict {
        return await insforge_insert("sensor_events", {
            "user_id": user_id,
            "sensor_type": sensor_type,
            "payload_json": payload,
            "derived_json": derived,
            "ts": now_iso()
        });
    }

    async def log_episode(
        user_id: str,
        episode_type: str,
        start_ts: str,
        end_ts: str,
        confidence: float,
        context_json: dict
    ) -> dict {
        return await insforge_insert("episode_log", {
            "user_id": user_id,
            "episode_type": episode_type,
            "start_ts": start_ts,
            "end_ts": end_ts,
            "confidence": confidence,
            "context_json": context_json
        });
    }

    async def backboard_read(query: str) -> dict {
        try {
            base_url = backboard_base_url();
            api_key = backboard_key();
            assistant_id = backboard_assistant_id();
            if not base_url or not api_key or not assistant_id {
                return {"ok": False, "reason": "missing_backboard_env", "memories": []};
            }
            res = await fetch(
                base_url + "/assistants/" + assistant_id + "/memories/search",
                {
                    "method": "POST",
                    "headers": {
                        "X-API-Key": api_key,
                        "Content-Type": "application/json"
                    },
                    "body": JSON.stringify({
                        "query": query,
                        "limit": 3
                    })
                }
            );

            if not res.ok {
                body_text = await res.text();
                print("backboard_read failed", res.status, body_text);
                return {"ok": False, "memories": []};
            }

            data = await res.json().catch(lambda -> Any { return {}; });
            return {
                "ok": True,
                "memories": (data.memories if data and data.memories else [])
            };
        } except Exception as e {
            print("backboard_read error", e);
            return {"ok": False, "memories": []};
        }
    }

    def day_code_from_date(d: Any) -> str {
        day_idx = d.getDay();
        days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        return days[day_idx] if day_idx is not None and day_idx >= 0 and day_idx < days.length else "UNK";
    }

    def fallback_meal_destination(day_code: str, hour: int) -> str {
        if hour >= 6 and hour < 11 {
            return "foo bar";
        }
        if hour >= 11 and hour < 15 {
            return "Downtown Lunch Hub";
        }
        if hour >= 15 and hour < 18 {
            return "Coffee Corner";
        }
        if day_code == "SAT" or day_code == "SUN" {
            return "Neighborhood Bistro";
        }
        return "City Food Court";
    }

    def extract_memory_destination(memory_result: dict) -> dict {
        memories = memory_result.memories if memory_result and memory_result.memories else [];
        if memories.length == 0 {
            return {
                "memory_destination": "",
                "memory_strength": 0,
                "memory_hits": 0
            };
        }

        first_memory = memories[0];
        content = String(first_memory.content if first_memory and first_memory.content else "");
        metadata = first_memory.metadata if first_memory and first_memory.metadata else {};

        destination = "";
        if metadata and metadata.destination_name {
            destination = String(metadata.destination_name);
        }

        if not destination and content {
            marker = "destination:";
            idx = content.toLowerCase().indexOf(marker);
            if idx >= 0 {
                start = idx + marker.length;
                raw_tail = content.slice(start).trim();
                comma_idx = raw_tail.indexOf(",");
                period_idx = raw_tail.indexOf(".");
                stop_idx = -1;
                if comma_idx >= 0 and period_idx >= 0 {
                    stop_idx = Math.min(comma_idx, period_idx);
                } elif comma_idx >= 0 {
                    stop_idx = comma_idx;
                } elif period_idx >= 0 {
                    stop_idx = period_idx;
                }
                destination = raw_tail.slice(0, stop_idx).trim() if stop_idx >= 0 else raw_tail;
            }
        }

        if not destination {
            destination = "";
        }

        score = Number(first_memory.score if first_memory and first_memory.score is not None else 0);
        if Number.isNaN(score) {
            score = 0;
        }

        return {
            "memory_destination": destination,
            "memory_strength": score,
            "memory_hits": memories.length
        };
    }

    async def backboard_write(namespace: str, content: str, metadata: dict = {}) -> dict {
        base_url = backboard_base_url();
        api_key = backboard_key();
        assistant_id = backboard_assistant_id();

        if not base_url or not api_key or not assistant_id {
            return {"ok": False, "reason": "missing_backboard_env"};
        }

        try {
            res = await fetch(
                base_url + "/assistants/" + assistant_id + "/memories",
                {
                    "method": "POST",
                    "headers": {
                        "X-API-Key": api_key,
                        "Content-Type": "application/json"
                    },
                    "body": JSON.stringify({
                        "content": "[" + namespace + "] " + content,
                        "metadata": Object.assign({
                            "namespace": namespace,
                            "user_id": "demo_user"
                        }, metadata)
                    })
                }
            );

            if not res.ok {
                body_text = await res.text();
                print("backboard_write failed", res.status, body_text);
                return {"ok": False};
            }

            return {"ok": True};
        } except Exception as e {
            print("backboard_write error", e);
            return {"ok": False};
        }
    }

    async def log_motion_from_walker(user_id: str, motion_data: Any, decision: dict) -> None {
        if not motion_data or not motion_data.acceleration {
            return;
        }

        accel = motion_data.acceleration;
        gyro = motion_data.rotationRate if motion_data and motion_data.rotationRate else {"alpha": 0, "beta": 0, "gamma": 0};

        accel_x = to_num(accel.x);
        accel_y = to_num(accel.y);
        accel_z = to_num(accel.z);
        gyro_x = to_num(gyro.alpha);
        gyro_y = to_num(gyro.beta);
        gyro_z = to_num(gyro.gamma);

        accel_norm = (accel_x * accel_x + accel_y * accel_y + accel_z * accel_z) ** 0.5;
        gyro_norm = (gyro_x * gyro_x + gyro_y * gyro_y + gyro_z * gyro_z) ** 0.5;

        await log_sensor_event(
            user_id,
            "motion_2hz",
            {
                "accel_x": accel_x,
                "accel_y": accel_y,
                "accel_z": accel_z,
                "gyro_x": gyro_x,
                "gyro_y": gyro_y,
                "gyro_z": gyro_z,
                "timestamp": (motion_data.timestamp if motion_data and motion_data.timestamp else Date.now())
            },
            {
                "accel_norm": accel_norm,
                "gyro_norm": gyro_norm,
                "is_flat": accel_norm >= 9.0 and accel_norm <= 10.8,
                "is_face_down": accel_z <= -7.5,
                "focus_mode_active": accel_z <= -7.5 and gyro_norm < 0.25,
                "walker_source": "MotionDecisionWalker",
                "decision_priority": (decision.priority if decision and decision.priority else 0)
            }
        );

        episode_type = None;
        context_json = None;
        if accel_z <= -7.5 and gyro_norm < 0.25 {
            episode_type = "face_down_stationary";
            context_json = {
                "duration_sec": 0,
                "avg_gyro_norm": gyro_norm,
                "detector_version": "v1",
                "source": "walker_motion_detector"
            };
        } elif decision and decision.priority and decision.priority > 0 and accel_norm >= 10.8 {
            episode_type = "pickup_transition";
            context_json = {
                "accel_spike": accel_norm,
                "gyro_spike": gyro_norm,
                "prior_episode": "face_down_stationary",
                "detector_version": "v1",
                "source": "walker_motion_detector"
            };
        }

        if episode_type {
            ts_iso = now_iso();
            await log_episode(
                user_id,
                episode_type,
                ts_iso,
                ts_iso,
                0.9,
                context_json
            );
        }
    }

    async def decide_motion_with_walker(
        motion_data: Any,
        config: dict,
        use_llm: bool = False
    ) -> dict {
        resp = root spawn MotionDecisionWalker(
            motion_data=motion_data,
            motion_threshold=config.motionThreshold,
            auto_act=config.autoAct,
            use_llm=use_llm
        );

        decision = {
            "type": "log",
            "message": "No decision returned",
            "priority": 0,
            "source": "rule"
        };

        if resp and resp.length and resp[0] {
            decision = resp[0];
        }
        if resp and resp.report and resp.report.length and resp.report[0] {
            decision = resp.report[0];
        }

        await log_motion_from_walker("demo_user", motion_data, decision);
        return decision;
    }

    def:pub app -> JsxElement {
        [isTracking, setIsTracking] = useState(False);
        [sensorData, setSensorData] = useState({
            "motion": None,
            "barometer": None,
            "compass": None,
            "geolocation": None,
            "pedometer": None,
            "proximity": None,
            "device": None,
            "camera": None
        });
        motionRef = useRef(None);
        barometerRef = useRef(None);
        compassRef = useRef(None);
        geolocationRef = useRef(None);
        [lastPhoto, setLastPhoto] = useState(None);
        [isRecording, setIsRecording] = useState(False);
        [decisions, setDecisions] = useState([]);
        [capabilities, setCapabilities] = useState(None);
        [agentRunning, setAgentRunning] = useState(False);
        [rules, setRules] = useState([
            {
                "id": "default-motion-notify",
                "name": "High motion notify",
                "enabled": True,
                "condition": {
                    "type": "motion_intensity_gt",
                    "value": 6.0
                },
                "action": {
                    "type": "notify",
                    "value": "High motion detected"
                }
            }
        ]);
        [ruleDraft, setRuleDraft] = useState({
            "name": "",
            "conditionType": "motion_intensity_gt",
            "conditionValue": "5.0",
            "actionType": "notify",
            "actionValue": "Rule triggered"
        });

        decisionLoopRef = useRef(None);
        lastMotionRef = useRef(None);
        userIdRef = useRef("demo_user");
        geofenceInsideRef = useRef(None);
        lastGeofenceExitTsRef = useRef(0);
        accelSubRef = useRef(None);
        barometerSubRef = useRef(None);
        compassSubRef = useRef(None);
        geoWatchIdRef = useRef(None);
        motionIntervalRef = useRef(None);
        isTrackingRef = useRef(False);  # Persist tracking state for listener callbacks
        motionListenerAttached = useRef(False);  # Track if motion listener is already attached

        # Fall detection state
        fallImpactTsRef = useRef(0);  # Timestamp of detected impact spike
        fallStillnessStartRef = useRef(0);  # When stillness began after impact
        fallStillnessCountRef = useRef(0);  # Consecutive stillness readings
        fallOrientationChangeRef = useRef(False);  # Orientation changed from upright
        fallCountdownRef = useRef(None);  # Countdown timer interval
        [fallCountdown, setFallCountdown] = useState(0);  # Countdown seconds remaining (0 = no countdown)
        [fallDetected, setFallDetected] = useState(False);  # Whether fall is confirmed
        fallDetectionStarted = useRef(False);  # Track if fall detection listener is already running

        # Demo timer state (for Start Agent button)
        demoTimerRef = useRef(None);
        [demoCountdown, setDemoCountdown] = useState(0);

        # Passcode challenge state (for kidnap scenario)
        passcodeTimerRef = useRef(None);
        [showPasscodeChallenge, setShowPasscodeChallenge] = useState(False);
        [passcodeInput, setPasscodeInput] = useState("");
        [passcodeCountdown, setPasscodeCountdown] = useState(0);
        [passcodeAttempts, setPasscodeAttempts] = useState(0);
        [passcodeError, setPasscodeError] = useState("");
        
        # The correct passcode - in production this would be user-configured
        CORRECT_PASSCODE = "1234";
        
        # Weather data state
        [weatherData, setWeatherData] = useState(None);
        
        # Hardcoded location coordinates
        HARDCODED_LAT = 42.2929877;
        HARDCODED_LNG = -83.7166082;
        
        # Workflow prompt state
        [workflowPrompt, setWorkflowPrompt] = useState("Monitor for falls and alert emergency contacts");
        [workflowCreated, setWorkflowCreated] = useState(False);
        [isCreatingWorkflow, setIsCreatingWorkflow] = useState(False);

        # Next meal prediction state
        [isPredictingDestination, setIsPredictingDestination] = useState(False);
        [eatingPrediction, setEatingPrediction] = useState(None);
        [eatingPredictionError, setEatingPredictionError] = useState("");
        [mealOrderStatus, setMealOrderStatus] = useState("");
        [showVoiceInputUi, setShowVoiceInputUi] = useState(False);
        [voiceInputSecondsLeft, setVoiceInputSecondsLeft] = useState(0);
        [showSmsFallbackButton, setShowSmsFallbackButton] = useState(False);
        [lastTtsError, setLastTtsError] = useState("");
        [showVoiceReplay, setShowVoiceReplay] = useState(False);
        [predictionLoadingStep, setPredictionLoadingStep] = useState(0);
        [predictionLoadingLocation, setPredictionLoadingLocation] = useState("");
        predictionAnimRef = useRef(None);

        # ElevenLabs TTS state
        [ttsText, setTtsText] = useState("");
        [ttsLoading, setTtsLoading] = useState(False);
        [ttsPlaying, setTtsPlaying] = useState(False);
        ttsAudioRef = useRef(None);
        ttsUnlockedRef = useRef(False);

        agentConfig = {
            "apiEndpoint": "",
            "motionThreshold": 2.5,
            "decisionInterval": 3000,
            "autoAct": True
        };

        def gen_rule_id -> str {
            return "rule-" + String(Date.now()) + "-" + String(Math.floor(Math.random() * 1000));
        }

        async def detect_geofence_exit(geo: dict) -> None {
            if not geo {
                return;
            }

            geofence = office_geofence();

            lat = to_num(geo.lat);
            lng = to_num(geo.lng);
            distance_m = haversine_m(lat, lng, geofence.lat, geofence.lng);
            is_inside = distance_m <= geofence.radius_m;

            if geofenceInsideRef.current is None {
                geofenceInsideRef.current = is_inside;
                return;
            }

            was_inside = geofenceInsideRef.current;
            geofenceInsideRef.current = is_inside;

            if was_inside and not is_inside {
                now_ms = Date.now();
                if now_ms - lastGeofenceExitTsRef.current < 45000 {
                    return;
                }
                lastGeofenceExitTsRef.current = now_ms;

                speed = to_num(geo.speed);
                payload = {
                    "lat": lat,
                    "lng": lng,
                    "accuracy": to_num(geo.accuracy),
                    "speed": speed,
                    "distance_from_office_m": Math.round(distance_m)
                };
                derived = {
                    "near_office": False,
                    "exited_geofence": True,
                    "geofence_name": geofence.name,
                    "time_of_day": Reflect.construct(Date, []).getHours(),
                    "source": "walker_geofence_detector"
                };

                await log_sensor_event(userIdRef.current, "geolocation", payload, derived);

                ts_iso = now_iso();
                await log_episode(
                    userIdRef.current,
                    "geofence_exit",
                    ts_iso,
                    ts_iso,
                    0.98,
                    {
                        "geofence_name": geofence.name,
                        "distance_from_center_m": Math.round(distance_m),
                        "speed_mps": speed,
                        "detector_version": "v1",
                        "source": "walker_geofence_detector"
                    }
                );

                await backboard_write(
                    "geofence_patterns",
                    "user:" + userIdRef.current + " exited " + geofence.name + " geofence at " + ts_iso,
                    {
                        "event": "geofence_exit",
                        "distance_from_center_m": String(Math.round(distance_m))
                    }
                );

                setDecisions(lambda prev: list -> list {
                    return prev.slice(-9).concat([{
                        "type": "log",
                        "message": "Geofence exit detected: " + geofence.name,
                        "priority": 1,
                        "source": "geofence"
                    }]);
                });
            }
        }

        async def log_fall_event(
            confidence: float,
            accel_norm: float,
            gyro_norm: float,
            stillness_duration_ms: int
        ) -> None {
            ts_iso = now_iso();
            
            # Log to episode_log table
            await log_episode(
                userIdRef.current,
                "fall_detected",
                ts_iso,
                ts_iso,
                confidence,
                {
                    "accel_norm_at_impact": accel_norm,
                    "gyro_norm_at_stillness": gyro_norm,
                    "stillness_duration_ms": stillness_duration_ms,
                    "detector_version": "v1",
                    "source": "fall_detector"
                }
            );

            # Write to Backboard safety_events memory
            await backboard_write(
                "safety_events",
                "user:" + userIdRef.current + " fall detected at " + ts_iso + " confidence=" + String(confidence),
                {
                    "event": "fall_detected",
                    "confidence": String(confidence),
                    "accel_norm": String(accel_norm)
                }
            );
        }

        async def log_emergency_call_action(contact_number: str, contact_name: str) -> None {
            ts_iso = now_iso();

            # Log to action_log table
            await insforge_insert("action_log", {
                "user_id": userIdRef.current,
                "action_type": "call_emergency_contact",
                "target": contact_number,
                "context_json": {
                    "contact_name": contact_name,
                    "trigger": "fall_detected",
                    "countdown_completed": True
                },
                "ts": ts_iso
            });

            # Write to Backboard safety_events memory
            await backboard_write(
                "safety_events",
                "user:" + userIdRef.current + " emergency call placed to " + contact_name + " at " + ts_iso,
                {
                    "event": "emergency_call",
                    "contact": contact_number
                }
            );
        }

        async def execute_emergency_call -> None {
            contact = emergency_contact();
            contact_name = emergency_contact_name();

            print("EMERGENCY: Initiating call to " + contact_name + " at " + contact);

            # Log the action first
            await log_emergency_call_action(contact, contact_name);

            # Place the call using tel: URI - multiple approaches for reliability
            tel_uri = "tel:" + contact;
            print("EMERGENCY: Using tel URI: " + tel_uri);

            # Method 1: Create and click an anchor element (most reliable on mobile)
            try {
                link = document.createElement("a");
                link.href = tel_uri;
                link.style.display = "none";
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
                print("EMERGENCY: Call initiated via anchor click");
            } except Exception as e {
                print("EMERGENCY: Anchor method failed: " + String(e));

                # Method 2: Direct location change
                try {
                    window.location.href = tel_uri;
                    print("EMERGENCY: Call initiated via location.href");
                } except Exception as e2 {
                    print("EMERGENCY: location.href failed: " + String(e2));

                    # Method 3: window.open
                    try {
                        window.open(tel_uri, "_system");
                        print("EMERGENCY: Call initiated via window.open");
                    } except Exception as e3 {
                        print("EMERGENCY: All call methods failed!");
                    }
                }
            }

            setDecisions(lambda prev: list -> list {
                return prev.slice(-9).concat([{
                    "type": "trigger",
                    "message": "Emergency call placed to " + contact_name,
                    "priority": 3,
                    "source": "fall_detector"
                }]);
            });

            # Reset fall detection state
            setFallDetected(False);
            setFallCountdown(0);
        }

        def cancel_fall_countdown -> None {
            if fallCountdownRef.current {
                clearInterval(fallCountdownRef.current);
                fallCountdownRef.current = None;
            }
            setFallCountdown(0);
            setFallDetected(False);

            # Reset fall detection state
            fallImpactTsRef.current = 0;
            fallStillnessStartRef.current = 0;
            fallStillnessCountRef.current = 0;
            fallOrientationChangeRef.current = False;

            setDecisions(lambda prev: list -> list {
                return prev.slice(-9).concat([{
                    "type": "log",
                    "message": "Fall alert cancelled by user",
                    "priority": 1,
                    "source": "fall_detector"
                }]);
            });
        }

        # ============ PASSCODE CHALLENGE FUNCTIONS ============

        def start_passcode_challenge -> None {
            # Docstring removed
            print("SAFETY: Starting passcode challenge");
            
            setShowPasscodeChallenge(True);
            setPasscodeInput("");
            setPasscodeAttempts(0);
            setPasscodeError("");
            setPasscodeCountdown(60);  # 60 second timeout
            
            # Haptic feedback
            try {
                Haptics.vibrate({"duration": 500});
            } except Exception as e {
                print("Haptics error", e);
            }
            
            # Start countdown timer
            passcodeTimerRef.current = setInterval(
                lambda -> None {
                    setPasscodeCountdown(lambda prev: int -> int {
                        if prev <= 1 {
                            # Timeout - escalate to emergency call
                            clearInterval(passcodeTimerRef.current);
                            passcodeTimerRef.current = None;
                            print("SAFETY: Passcode timeout - escalating to emergency call");
                            on_passcode_timeout();
                            return 0;
                        }
                        return prev - 1;
                    });
                },
                1000
            );
            
            setDecisions(lambda prev: list -> list {
                return prev.slice(-9).concat([{
                    "type": "alert",
                    "message": "Safety check: Enter passcode to confirm you're OK",
                    "priority": 3,
                    "source": "safety_monitor"
                }]);
            });
        }
        
        def on_passcode_timeout -> None {
            # Docstring removed
            setShowPasscodeChallenge(False);
            setPasscodeInput("");
            setPasscodeError("");
            
            setDecisions(lambda prev: list -> list {
                return prev.slice(-9).concat([{
                    "type": "trigger",
                    "message": "Passcode timeout - initiating emergency call",
                    "priority": 3,
                    "source": "safety_monitor"
                }]);
            });
            
            # Start 30-second countdown before calling
            start_emergency_countdown_from_passcode();
        }
        
        def start_emergency_countdown_from_passcode -> None {
            # Docstring removed
            print("SAFETY: Starting emergency countdown after passcode failure");
            
            setFallDetected(True);  # Reuse fall detected UI for countdown
            setFallCountdown(30);
            
            # Haptic pattern
            try {
                Haptics.vibrate({"duration": 1000});
            } except Exception as e {
                ;
            }
            
            fallCountdownRef.current = setInterval(
                lambda -> None {
                    setFallCountdown(lambda prev: int -> int {
                        if prev <= 1 {
                            clearInterval(fallCountdownRef.current);
                            fallCountdownRef.current = None;
                            execute_emergency_call();
                            return 0;
                        }
                        # Vibrate every 5 seconds
                        if prev % 5 == 0 {
                            try {
                                Haptics.vibrate({"duration": 200});
                            } except Exception as e {
                                ;
                            }
                        }
                        return prev - 1;
                    });
                },
                1000
            );
        }
        
        def verify_passcode(entered: str) -> None {
            # Docstring removed
            print("SAFETY: Verifying passcode attempt");
            
            if entered == CORRECT_PASSCODE {
                # Correct passcode - user is safe
                print("SAFETY: Passcode verified - user is OK");
                
                if passcodeTimerRef.current {
                    clearInterval(passcodeTimerRef.current);
                    passcodeTimerRef.current = None;
                }
                
                setShowPasscodeChallenge(False);
                setPasscodeInput("");
                setPasscodeCountdown(0);
                setPasscodeError("");
                setPasscodeAttempts(0);
                
                # Success haptic
                try {
                    Haptics.notification({"type": "success"});
                } except Exception as e {
                    ;
                }
                
                setDecisions(lambda prev: list -> list {
                    return prev.slice(-9).concat([{
                        "type": "log",
                        "message": "Safety verified - passcode correct",
                        "priority": 1,
                        "source": "safety_monitor"
                    }]);
                });
            } else {
                # Wrong passcode
                attempts = passcodeAttempts + 1;
                setPasscodeAttempts(attempts);
                setPasscodeInput("");
                
                # Error haptic
                try {
                    Haptics.notification({"type": "error"});
                } except Exception as e {
                    ;
                }
                
                if attempts >= 3 {
                    # Too many attempts - escalate
                    print("SAFETY: 3 failed attempts - escalating");
                    
                    if passcodeTimerRef.current {
                        clearInterval(passcodeTimerRef.current);
                        passcodeTimerRef.current = None;
                    }
                    
                    setShowPasscodeChallenge(False);
                    setPasscodeError("");
                    
                    setDecisions(lambda prev: list -> list {
                        return prev.slice(-9).concat([{
                            "type": "trigger",
                            "message": "3 failed passcode attempts - initiating emergency call",
                            "priority": 3,
                            "source": "safety_monitor"
                        }]);
                    });
                    
                    start_emergency_countdown_from_passcode();
                } else {
                    setPasscodeError("Wrong passcode. " + String(3 - attempts) + " attempts remaining.");
                }
            }
        }
        
        def cancel_passcode_challenge -> None {
            # Docstring removed
            if passcodeTimerRef.current {
                clearInterval(passcodeTimerRef.current);
                passcodeTimerRef.current = None;
            }
            setShowPasscodeChallenge(False);
            setPasscodeInput("");
            setPasscodeCountdown(0);
            setPasscodeError("");
            setPasscodeAttempts(0);
        }

        # ============ DEMO TIMER FUNCTIONS ============

        def start_demo_timer -> None {
            # Docstring removed
            print("DEMO: Starting 6-second demo timer (overlay shows last 3 seconds)");
            
            # Start at 6, but overlay only shows when <= 3
            setDemoCountdown(6);
            
            # Haptic feedback
            try {
                Haptics.vibrate({"duration": 300});
            } except Exception as e {
                ;
            }
            
            demoTimerRef.current = setInterval(
                lambda -> None {
                    setDemoCountdown(lambda prev: int -> int {
                        if prev <= 1 {
                            clearInterval(demoTimerRef.current);
                            demoTimerRef.current = None;
                            print("DEMO: Timer complete - calling emergency contact");
                            execute_emergency_call();
                            return 0;
                        }
                        # Vibrate each second when visible (last 3 seconds)
                        if prev <= 4 {
                            try {
                                Haptics.vibrate({"duration": 100});
                            } except Exception as e {
                                ;
                            }
                        }
                        return prev - 1;
                    });
                },
                1000
            );
            
            setDecisions(lambda prev: list -> list {
                return prev.slice(-9).concat([{
                    "type": "alert",
                    "message": "Demo mode: Emergency call in 6 seconds",
                    "priority": 3,
                    "source": "demo"
                }]);
            });
        }
        
        def cancel_demo_timer -> None {
            if demoTimerRef.current {
                clearInterval(demoTimerRef.current);
                demoTimerRef.current = None;
            }
            setDemoCountdown(0);
            
            setDecisions(lambda prev: list -> list {
                return prev.slice(-9).concat([{
                    "type": "log",
                    "message": "Demo timer cancelled",
                    "priority": 1,
                    "source": "demo"
                }]);
            });
        }

        def create_workflow -> None {
            print("Creating workflow...");
            setIsCreatingWorkflow(True);
            
            # Simulate workflow creation delay
            setTimeout(
                lambda -> None {
                    setIsCreatingWorkflow(False);
                    # Just log success and return to form (don't show Fall Detection Active screen)
                    setDecisions(lambda prev: list -> list {
                        return prev.slice(-9).concat([{
                            "type": "log",
                            "message": "Workflow created successfully",
                            "priority": 1,
                            "source": "workflow"
                        }]);
                    });
                },
                1500
            );
        }

        async def play_tts -> None {
            if not ttsText or ttsText.trim().length == 0 {
                return;
            }

            setTtsLoading(True);
            result = await speak_text(ttsText.trim());

            if result and result.ok and result.audio_url {
                audio = Reflect.construct(Audio, [result.audio_url]);
                ttsAudioRef.current = audio;
                
                audio.onended = lambda -> None {
                    setTtsPlaying(False);
                    URL.revokeObjectURL(result.audio_url);
                };

                audio.play();
                setTtsPlaying(True);
            } else {
                setDecisions(lambda prev: list -> list {
                    return prev.slice(-9).concat([{
                        "type": "notify",
                        "message": "TTS failed: " + (result.reason if result and result.reason else "unknown error"),
                        "priority": 1,
                        "source": "tts"
                    }]);
                });
            }

            setTtsLoading(False);
        }

        def stop_tts -> None {
            if ttsAudioRef.current {
                ttsAudioRef.current.pause();
                ttsAudioRef.current = None;
            }
            setTtsPlaying(False);
        }

        def unlock_audio_output -> None {
            if ttsUnlockedRef.current {
                print("unlock_audio_output: Already unlocked");
                return;
            }

            print("unlock_audio_output: Attempting to unlock audio context");

            # First try to resume AudioContext if available (Web Audio API)
            try {
                audio_context = Reflect.get(window, "AudioContext") or Reflect.get(window, "webkitAudioContext");
                if audio_context {
                    ctx = Reflect.construct(audio_context, []);
                    if ctx.state == "suspended" {
                        ctx.resume().then(lambda -> None {
                            print("unlock_audio_output: AudioContext resumed");
                        }).catch(lambda -> None { ; });
                    }
                }
            } except Exception as e {
                ;
            }

            warm_candidates = ["/order.mp3", "./order.mp3", "capacitor://localhost/order.mp3"];

            def try_warm(idx: int) -> None {
                if idx >= warm_candidates.length {
                    print("unlock_audio_output: All warm candidates exhausted");
                    return;
                }

                warm_src = warm_candidates[idx];
                print("unlock_audio_output: Trying warm candidate " + String(idx) + ": " + warm_src);
                try {
                    warm_audio = Reflect.construct(Audio, [warm_src]);
                    warm_audio.muted = True;
                    warm_audio.volume = 0;
                    warm_audio.play().then(lambda -> None {
                        warm_audio.pause();
                        warm_audio.currentTime = 0;
                        warm_audio.muted = False;
                        warm_audio.volume = 1;
                        ttsUnlockedRef.current = True;
                        print("unlock_audio_output: Successfully unlocked with " + warm_src);
                    }).catch(lambda err: Any -> None {
                        print("unlock_audio_output: Warm candidate " + warm_src + " failed: " + String(err));
                        try_warm(idx + 1);
                    });
                } except Exception as e {
                    print("unlock_audio_output: Exception with " + warm_src + ": " + String(e));
                    try_warm(idx + 1);
                }
            }

            try_warm(0);
        }

        def speak_browser_fallback(text: str) -> bool {
            try {
                synth = Reflect.get(globalThis, "speechSynthesis");
                utter_ctor = Reflect.get(globalThis, "SpeechSynthesisUtterance");
                if synth and utter_ctor {
                    utter = Reflect.construct(utter_ctor, [text]);
                    utter.rate = 1.0;
                    utter.pitch = 1.0;
                    utter.volume = 1.0;
                    synth.cancel();
                    synth.speak(utter);
                    return True;
                }
            } except Exception as e {
                ;
            }
            return False;
        }

        def play_local_audio(file_name: str) -> None {
            if not file_name or file_name.trim().length == 0 {
                print("play_local_audio: No file name provided");
                return;
            }

            print("play_local_audio: Attempting to play " + file_name);
            Haptics.impact({"style": ImpactStyle.Light}).catch(lambda -> None { ; });

            origin = "";
            try {
                origin = String(window.location.origin if window and window.location and window.location.origin else "");
            } except Exception as e {
                ;
            }

            candidates = [
                "/" + file_name,
                "./" + file_name,
                file_name,
                "capacitor://localhost/" + file_name,
                origin + "/" + file_name if origin and origin.length > 0 else ""
            ];

            def try_play_candidate(idx: int) -> None {
                if idx >= candidates.length {
                    print("play_local_audio: All candidates failed for " + file_name);
                    setTtsPlaying(False);
                    setShowVoiceReplay(True);
                    setLastTtsError("audio_play_failed_" + file_name);
                    return;
                }

                src = candidates[idx];
                if not src or src.trim().length == 0 {
                    try_play_candidate(idx + 1);
                    return;
                }
                
                print("play_local_audio: Trying candidate " + String(idx) + ": " + src);
                
                try {
                    audio = Reflect.construct(Audio, [src]);
                    audio.preload = "auto";
                    audio.playsInline = True;
                    audio.muted = False;
                    audio.volume = 1;
                    ttsAudioRef.current = audio;
                    setTtsPlaying(True);
                    audio.onended = lambda -> None {
                        print("play_local_audio: Playback ended for " + file_name);
                        setTtsPlaying(False);
                    };
                    audio.onerror = lambda e: Any -> None {
                        print("play_local_audio: Error event for " + src + ": " + String(e));
                        try_play_candidate(idx + 1);
                    };
                    audio.play().then(lambda -> None {
                        print("play_local_audio: Successfully playing " + src);
                        setShowVoiceReplay(False);
                    }).catch(lambda err: Any -> None {
                        print("play_local_audio: play() rejected for " + src + ": " + String(err));
                        try_play_candidate(idx + 1);
                    });
                } except Exception as e {
                    print("play_local_audio: Exception creating audio for " + src + ": " + String(e));
                    try_play_candidate(idx + 1);
                }
            }

            try {
                try_play_candidate(0);
            } except Exception as e {
                print("play_local_audio: Fatal error: " + String(e));
                setShowVoiceReplay(True);
                setLastTtsError("audio_init_failed_" + file_name);
            }
        }

        def queue_local_audio(file_name: str) -> None {
            current_audio = ttsAudioRef.current;
            if current_audio and not current_audio.paused {
                prior_onended = current_audio.onended;
                current_audio.onended = lambda -> None {
                    if prior_onended {
                        prior_onended();
                    }
                    play_local_audio(file_name);
                };
                return;
            }
            play_local_audio(file_name);
        }

        def force_play_audio_sequence -> None {
            unlock_audio_output();
            setLastTtsError("forced_audio_sequence");
            setMealOrderStatus("Playing prompt audio...");
            play_local_audio("order.mp3");
            setTimeout(lambda -> None {
                setMealOrderStatus("Playing confirmation audio...");
                queue_local_audio("spicy-chicken-bowl.mp3");
            }, 2200);
        }

    def open_sms_invite_after_llm -> None {
        sms_body = "you wanna join me for a quick bite rn?";
        sms_number = emergency_contact();
        sms_url = "sms:" + sms_number + "?body=" + encodeURIComponent(sms_body);
        did_open = False;

        # Method 1: Create and click anchor element (most reliable for SMS on mobile)
        try {
            link = document.createElement("a");
            link.href = sms_url;
            link.style.display = "none";
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            did_open = True;
            print("SMS: Opened via anchor click");
        } except Exception as e {
            print("SMS: Anchor click failed: " + String(e));
            did_open = False;
        }

        if not did_open {
            try {
                window.location.href = sms_url;
                did_open = True;
                print("SMS: Opened via location.href");
            } except Exception as e {
                print("SMS: location.href failed: " + String(e));
                did_open = False;
            }
        }

        if not did_open {
            setShowSmsFallbackButton(True);
            setEatingPredictionError("SMS app did not open automatically. Tap the SMS button below.");
        }
    }

        def speak_assistant_prompt(text: str) -> None {
            if not text or text.trim().length == 0 {
                return;
            }

            setLastTtsError("");
            unlock_audio_output();

            normalized = text.trim().toLowerCase();
            
            # Check for order prompt (with typo match for backwards compatibility)
            if normalized == "do you wnat to place your usual order?" or normalized == "do you want to place your usual order?" {
                print("TTS: Playing order.mp3 for order prompt");
                Haptics.impact({"style": ImpactStyle.Light}).catch(lambda -> None { ; });
                play_local_audio("order.mp3");
                return;
            }

            # Check for spicy chicken bowl response
            if normalized.indexOf("spicy chicken bowl") >= 0 {
                print("TTS: Playing spicy-chicken-bowl.mp3");
                Haptics.impact({"style": ImpactStyle.Light}).catch(lambda -> None { ; });
                play_local_audio("spicy-chicken-bowl.mp3");
                return;
            }

            # Try browser speech synthesis fallback
            used_browser = speak_browser_fallback(text.trim());
            if used_browser {
                print("TTS: Used browser speech synthesis");
                setShowVoiceReplay(False);
                return;
            }

            # No audio available
            print("TTS: No audio method available for: " + text);
            setShowVoiceReplay(True);
            Haptics.impact({"style": ImpactStyle.Medium}).catch(lambda -> None { ; });
            setDecisions(lambda prev: list -> list {
                return prev.slice(-9).concat([{
                    "type": "notify",
                    "message": "Voice unavailable on this device. Continuing with text prompt.",
                    "priority": 1,
                    "source": "tts"
                }]);
            });
        }

        def test_local_audio -> None {
            unlock_audio_output();
            setMealOrderStatus("Audio test started...");
            setLastTtsError("audio_test_invoked");
            Haptics.impact({"style": ImpactStyle.Heavy}).catch(lambda -> None { ; });
            play_local_audio("order.mp3");
            setTimeout(lambda -> None {
                queue_local_audio("spicy-chicken-bowl.mp3");
                setMealOrderStatus("Audio test second clip queued");
            }, 2200);
        }

        def debug_audio_ping -> None {
            now = Reflect.construct(Date, []);
            setEatingPredictionError("Audio ping clicked at " + now.toLocaleTimeString());
            setLastTtsError("audio_ping_clicked");
            Haptics.impact({"style": ImpactStyle.Heavy}).catch(lambda -> None { ; });
            play_local_audio("order.mp3");
            setDecisions(lambda prev: list -> list {
                return prev.slice(-9).concat([{
                    "type": "notify",
                    "message": "Audio ping fired",
                    "priority": 1,
                    "source": "audio_debug"
                }]);
            });
        }

        def open_sms_fallback -> None {
            sms_body = "you wanna join me for a quick bite rn?";
            sms_number = emergency_contact();
            sms_url = "sms:" + sms_number + "?body=" + encodeURIComponent(sms_body);
            try {
                window.location.href = sms_url;
            } except Exception as e {
                setEatingPredictionError("Could not open SMS app. Please send manually.");
            }
        }
        def predict_next_eating_destination -> None {
            if isPredictingDestination {
                return;
            }

            unlock_audio_output();

            setIsPredictingDestination(True);
            setEatingPredictionError("");
            setMealOrderStatus("");
            setShowVoiceInputUi(False);
            setVoiceInputSecondsLeft(0);
            setShowSmsFallbackButton(False);
            setLastTtsError("");
            setShowVoiceReplay(False);

            geo = sensorData.geolocation if sensorData and sensorData.geolocation else None;
            loc_lat = geo.lat if geo and geo.lat is not None else HARDCODED_LAT;
            loc_lng = geo.lng if geo and geo.lng is not None else HARDCODED_LNG;
            setPredictionLoadingLocation(String(loc_lat) + ", " + String(loc_lng));
            setPredictionLoadingStep(0);

            if predictionAnimRef.current {
                clearInterval(predictionAnimRef.current);
                predictionAnimRef.current = None;
            }

            predictionAnimRef.current = setInterval(
                lambda -> None {
                    setPredictionLoadingStep(lambda prev: int -> int {
                        next_step = prev + 1;
                        if next_step >= 3 {
                            clearInterval(predictionAnimRef.current);
                            predictionAnimRef.current = None;

                            now = Reflect.construct(Date, []);
                            hour = now.getHours();
                            day_code = day_code_from_date(now);

                            pred = {
                                "destination_name": fallback_meal_destination(day_code, hour),
                                "confidence_pct": 72 if (hour >= 11 and hour <= 14) else (68 if hour >= 18 else 61),
                                "reason": "Demo prediction from current time/day window",
                                "source": "hardcoded-demo",
                                "day_of_week": day_code,
                                "hour": hour
                            };

                            if day_code == "SAT" or day_code == "SUN" {
                                pred.destination_name = "Neighborhood Bistro";
                                pred.confidence_pct = 76;
                                pred.reason = "Demo weekend pattern";
                            }

                            if hour >= 6 and hour < 10 {
                                pred.destination_name = "foo bar";
                                pred.confidence_pct = 74;
                            } elif hour >= 15 and hour < 18 {
                                pred.destination_name = "Coffee Corner";
                                pred.confidence_pct = 69;
                            }

                            setEatingPrediction(pred);
                            setIsPredictingDestination(False);

                            setMealOrderStatus("Assistant: do you wnat to place your usual order?");
                            speak_assistant_prompt("do you wnat to place your usual order?");

                            setTimeout(
                                lambda -> None {
                                    setShowVoiceInputUi(True);
                                    setVoiceInputSecondsLeft(4);

                                    voiceTickRef = {"id": None};
                                    voiceTickRef.id = setInterval(
                                        lambda -> None {
                                            setVoiceInputSecondsLeft(lambda prev: int -> int {
                                                next_left = prev - 1;
                                                if next_left <= 0 {
                                                    if voiceTickRef.id {
                                                        clearInterval(voiceTickRef.id);
                                                        voiceTickRef.id = None;
                                                    }
                                                    setShowVoiceInputUi(False);
                                                    setMealOrderStatus("Sure! placed your usual spicy chicken bowl.");
                                                    setShowVoiceReplay(False);
                                                    queue_local_audio("spicy-chicken-bowl.mp3");
                                                    setDecisions(lambda prev2: list -> list {
                                                        return prev2.slice(-9).concat([{
                                                            "type": "notify",
                                                            "message": "Sure! placed your usual spicy chicken bowl.",
                                                            "priority": 1,
                                                            "source": "meal_order"
                                                        }]);
                                                    });
                                                    setTimeout(lambda -> None {
                                                        open_sms_invite_after_llm();
                                                    }, 300);
                                                    return 0;
                                                }
                                                return next_left;
                                            });
                                        },
                                        1000
                                    );
                                },
                                1200
                            );

                            setDecisions(lambda prev: list -> list {
                                return prev.slice(-9).concat([{
                                    "type": "notify",
                                    "message": "Next meal spot: " + pred.destination_name + " (" + String(pred.confidence_pct) + "%)",
                                    "priority": 1,
                                    "source": "meal_predictor"
                                }]);
                            });

                            return 3;
                        }
                        return next_step;
                    });
                },
                1000
            );
        }

        def start_fall_countdown(confidence: float, accel_norm: float, gyro_norm: float, stillness_ms: int) -> None {
            thresholds = fall_detection_thresholds();
            countdown_secs = thresholds.countdown_seconds;

            setFallDetected(True);
            setFallCountdown(countdown_secs);

            # Log the fall event
            log_fall_event(confidence, accel_norm, gyro_norm, stillness_ms);

            # Haptic feedback to alert user
            Haptics.impact({"style": ImpactStyle.Heavy}).catch(lambda -> None { ; });

            # Start countdown timer
            fallCountdownRef.current = setInterval(
                lambda -> None {
                    setFallCountdown(lambda prev: int -> int {
                        if prev <= 1 {
                            # Countdown finished, place emergency call
                            clearInterval(fallCountdownRef.current);
                            fallCountdownRef.current = None;
                            execute_emergency_call();
                            return 0;
                        }
                        # Haptic tick every 5 seconds
                        if prev % 5 == 0 {
                            Haptics.impact({"style": ImpactStyle.Medium}).catch(lambda -> None { ; });
                        }
                        return prev - 1;
                    });
                },
                1000
            );

            setDecisions(lambda prev: list -> list {
                return prev.slice(-9).concat([{
                    "type": "trigger",
                    "message": "Fall detected! Emergency call in " + String(countdown_secs) + "s",
                    "priority": 3,
                    "source": "fall_detector"
                }]);
            });
        }

        def detect_fall(accel_x: float, accel_y: float, accel_z: float, gyro_x: float, gyro_y: float, gyro_z: float) -> None {
            # Don't process if countdown is already active
            if fallCountdown > 0 {
                return;
            }

            thresholds = fall_detection_thresholds();
            now_ms = Date.now();

            accel_norm = (accel_x * accel_x + accel_y * accel_y + accel_z * accel_z) ** 0.5;
            gyro_norm = (gyro_x * gyro_x + gyro_y * gyro_y + gyro_z * gyro_z) ** 0.5;

            # Calculate orientation - angle from upright (z-axis should be ~9.8 when upright)
            # If accel_z is significantly different from accel_norm, device is tilted
            orientation_from_upright = 0.0;
            if accel_norm > 0.1 {
                cos_angle = accel_z / accel_norm;
                # Clamp to valid range for acos
                if cos_angle > 1.0 {
                    cos_angle = 1.0;
                }
                if cos_angle < -1.0 {
                    cos_angle = -1.0;
                }
                orientation_from_upright = Math.acos(cos_angle) * (180.0 / Math.PI);
            }

            impact_ts = fallImpactTsRef.current;

            # Stage 1: Detect impact spike (only if we don't have a recent impact already)
            if accel_norm > thresholds.impact_accel_norm {
                # Only register new impact if no impact in last 500ms (debounce multiple spikes)
                if impact_ts == 0 or (now_ms - impact_ts) > 500 {
                    fallImpactTsRef.current = now_ms;
                    fallStillnessCountRef.current = 0;
                    fallStillnessStartRef.current = 0;
                    fallOrientationChangeRef.current = False;
                    print("Fall detection: Impact spike detected, accel_norm=" + String(accel_norm));
                }
                return;
            }

            # Stage 2: After impact, check for stillness
            if impact_ts > 0 and (now_ms - impact_ts) < 10000 {
                time_since_impact = now_ms - impact_ts;

                # Within 10 seconds of impact, check for stillness
                if gyro_norm < thresholds.stillness_gyro_norm {
                    if fallStillnessStartRef.current == 0 {
                        fallStillnessStartRef.current = now_ms;
                        print("Fall detection: Stillness started, gyro_norm=" + String(gyro_norm));
                    }
                    fallStillnessCountRef.current = fallStillnessCountRef.current + 1;

                    stillness_duration = now_ms - fallStillnessStartRef.current;

                    # Stage 3: Check orientation change
                    if orientation_from_upright > thresholds.orientation_change_deg {
                        if not fallOrientationChangeRef.current {
                            print("Fall detection: Orientation change detected, angle=" + String(orientation_from_upright) + " deg");
                        }
                        fallOrientationChangeRef.current = True;
                    }

                    # Log progress every second
                    if fallStillnessCountRef.current % 60 == 0 {
                        print("Fall detection: Stillness=" + String(stillness_duration) + "ms, orientation=" + String(orientation_from_upright) + "deg, orientationOK=" + String(fallOrientationChangeRef.current));
                    }

                    # All conditions met?
                    if stillness_duration >= thresholds.stillness_duration_ms and fallOrientationChangeRef.current {
                        # Calculate confidence based on conditions
                        confidence = 0.85;
                        if stillness_duration > 5000 {
                            confidence = confidence + 0.05;
                        }
                        if orientation_from_upright > 90.0 {
                            confidence = confidence + 0.05;
                        }
                        if confidence > 1.0 {
                            confidence = 1.0;
                        }

                        if confidence >= thresholds.confidence_threshold {
                            print("Fall confirmed! confidence=" + String(confidence) + ", stillness=" + String(stillness_duration) + "ms");

                            # Reset detection state (countdown will handle the rest)
                            fallImpactTsRef.current = 0;
                            fallStillnessStartRef.current = 0;
                            fallStillnessCountRef.current = 0;
                            fallOrientationChangeRef.current = False;

                            # Start countdown
                            start_fall_countdown(
                                confidence,
                                accel_norm,
                                gyro_norm,
                                stillness_duration
                            );
                        }
                    }
                } else {
                    # Movement detected, reset stillness tracking
                    if fallStillnessStartRef.current > 0 {
                        print("Fall detection: Movement detected, resetting stillness. gyro_norm=" + String(gyro_norm));
                    }
                    fallStillnessStartRef.current = 0;
                    fallStillnessCountRef.current = 0;
                }
            } elif impact_ts > 0 and (now_ms - impact_ts) >= 10000 {
                # Too much time passed since impact, reset
                print("Fall detection: Impact timeout (10s), resetting");
                fallImpactTsRef.current = 0;
                fallStillnessStartRef.current = 0;
                fallStillnessCountRef.current = 0;
                fallOrientationChangeRef.current = False;
            }
        }

        async def execute_action(action: dict, reason: str = "") -> None {
            action_type = action.type if action and action.type else "notify";
            action_value = action.value if action and action.value else "";

            if action_type == "maps_home" {
                query = action_value if action_value else "Home";
                try {
                    window.open("geo:0,0?q=" + encodeURIComponent(query), "_blank");
                } except Exception as e {
                    window.open(
                        "https://www.google.com/maps/search/?api=1&query="
                        + encodeURIComponent(query),
                        "_blank"
                    );
                }
                setDecisions(lambda prev: list -> list {
                    return prev.slice(-9).concat([{
                        "type": "trigger",
                        "message": "Opened Maps for " + query,
                        "priority": 2,
                        "source": "action"
                    }]);
                });
                return;
            }

            if action_type == "webhook" {
                if not action_value {
                    setDecisions(lambda prev: list -> list {
                        return prev.slice(-9).concat([{
                            "type": "notify",
                            "message": "Webhook action skipped: missing URL",
                            "priority": 1,
                            "source": "action"
                        }]);
                    });
                    return;
                }
                try {
                    await fetch(action_value, {
                        "method": "POST",
                        "headers": {
                            "Content-Type": "application/json"
                        },
                        "body": JSON.stringify({
                            "source": "hijac-sensor-agent",
                            "reason": reason,
                            "timestamp": Date.now(),
                            "sensor": sensorData
                        })
                    });
                    setDecisions(lambda prev: list -> list {
                        return prev.slice(-9).concat([{
                            "type": "trigger",
                            "message": "Webhook sent",
                            "priority": 2,
                            "source": "action"
                        }]);
                    });
                } except Exception as e {
                    setDecisions(lambda prev: list -> list {
                        return prev.slice(-9).concat([{
                            "type": "notify",
                            "message": "Webhook failed",
                            "priority": 1,
                            "source": "action"
                        }]);
                    });
                }
                return;
            }

            message = action_value if action_value else "Sensor action triggered";
            try {
                if Notification and Notification.permission == "granted" {
                    Notification("Hijac Agent", {"body": message});
                } else {
                    alert("Hijac: " + message);
                }
            } except Exception as e {
                alert("Hijac: " + message);
            }

            try {
                await Haptics.impact({"style": ImpactStyle.Medium});
            } except Exception as e {
                ;
            }

            setDecisions(lambda prev: list -> list {
                return prev.slice(-9).concat([{
                    "type": "notify",
                    "message": message,
                    "priority": 1,
                    "source": "action"
                }]);
            });
        }

        async def evaluate_rules_and_act(motion_data: Any, source: str = "rule") -> None {
            if not motion_data {
                return;
            }

            accel = motion_data.acceleration if motion_data.acceleration else {"x": 0, "y": 0, "z": 0};
            intensity = ((accel.x * accel.x) + (accel.y * accel.y) + (accel.z * accel.z)) ** 0.5;

            for rule in rules {
                if not rule.enabled {
                    continue;
                }

                condition = rule.condition if rule.condition else {};
                cond_type = condition.type if condition.type else "motion_intensity_gt";
                cond_value = Number(condition.value if condition.value else 0);
                matched = False;

                if cond_type == "motion_intensity_gt" {
                    matched = intensity > cond_value;
                } elif cond_type == "speed_gt" {
                    speed = 0;
                    if geolocationRef.current and geolocationRef.current.speed {
                        speed = geolocationRef.current.speed;
                    }
                    matched = speed > cond_value;
                }

                if matched {
                    await execute_action(
                        rule.action,
                        source + ": " + rule.name + " (value=" + String(round(intensity, 2)) + ")"
                    );
                }
            }
        }

        def add_rule -> None {
            name = ruleDraft.name.trim() if ruleDraft.name else "New Rule";
            cond_value = Number(ruleDraft.conditionValue);
            rule = {
                "id": gen_rule_id(),
                "name": name,
                "enabled": True,
                "condition": {
                    "type": ruleDraft.conditionType,
                    "value": (cond_value if not Number.isNaN(cond_value) else 0)
                },
                "action": {
                    "type": ruleDraft.actionType,
                    "value": ruleDraft.actionValue
                }
            };
            setRules(lambda prev: list -> list {
                return prev.concat([rule]);
            });
            setRuleDraft({
                "name": "",
                "conditionType": "motion_intensity_gt",
                "conditionValue": "5.0",
                "actionType": "notify",
                "actionValue": "Rule triggered"
            });
        }

        def toggle_rule(rule_id: str) -> None {
            setRules(lambda prev: list -> list {
                return prev.map(lambda r: Any -> Any {
                    if r.id == rule_id {
                        next_rule = Object.assign({}, r);
                        next_rule.enabled = not r.enabled;
                        return next_rule;
                    }
                    return r;
                });
            });
        }

        def remove_rule(rule_id: str) -> None {
            setRules(lambda prev: list -> list {
                return prev.filter(lambda r: Any -> bool { return r.id != rule_id; });
            });
        }

        async def simulate_sensor_event -> None {
            # Docstring removed
            print("KIDNAP SIMULATION: Starting kidnap scenario simulation");
            
            # Simulate erratic gyroscope data indicating struggle
            # Based on BACKEND.md: variance > 1.5 rad/s² on 2+ axes = struggle
            mock_motion = {
                "acceleration": {
                    "x": 12.5,  # Higher than normal - being jostled
                    "y": 8.3,
                    "z": 15.2
                },
                "rotationRate": {
                    # High variance values indicating struggle
                    "alpha": 85.0,  # Erratic rotation
                    "beta": 72.0,
                    "gamma": 63.0
                },
                "timestamp": Date.now()
            };
            motionRef.current = mock_motion;
            lastMotionRef.current = mock_motion;
            
            # Set location to unfamiliar area (far from normal locations)
            # Based on BACKEND.md: >2km from centroid = medium concern
            geolocationRef.current = {
                "lat": 37.8100,   # ~4km from normal centroid (37.7749)
                "lng": -122.4700,
                "alt": 5.0,
                "speed": 15.5,  # Moving fast (in a vehicle?)
                "accuracy": 15.0
            };
            emit_data();
            
            # Log the struggle detection
            setDecisions(lambda prev: list -> list {
                return prev.slice(-9).concat([{
                    "type": "alert",
                    "message": "⚠️ KIDNAP SCENARIO: Struggle detected + Location anomaly (4km from safe zone)",
                    "priority": 3,
                    "source": "safety_monitor"
                }]);
            });
            
            # Haptic alert
            try {
                Haptics.vibrate({"duration": 800});
            } except Exception as e {
                ;
            }
            
            # Start passcode challenge (as per BACKEND.md section 7.2)
            # Medium/High concern from struggle + location = passcode_challenge
            print("KIDNAP SIMULATION: Triggering passcode challenge");
            start_passcode_challenge();
        }

        def simulate_fall -> None {
            # Directly trigger fall detection countdown for testing
            print("FALL SIMULATION: Triggering fall detection");
            
            thresholds = fall_detection_thresholds();
            
            # Log fall event
            log_fall_event(0.95, 28.0, 0.05, 3500);
            
            # Haptic feedback
            try {
                Haptics.impact({"style": ImpactStyle.Heavy});
            } except Exception as e {
                ;
            }
            
            # Start the countdown
            start_fall_countdown(0.95, 28.0, 0.05, 3500);
            
            setDecisions(lambda prev: list -> list {
                return prev.slice(-9).concat([{
                    "type": "trigger",
                    "message": "SIMULATED: Fall detected! Emergency countdown started",
                    "priority": 3,
                    "source": "fall_detector"
                }]);
            });
        }

        def emit_data -> None {
            setSensorData({
                "motion": motionRef.current,
                "barometer": barometerRef.current,
                "compass": compassRef.current,
                "geolocation": geolocationRef.current,
                "pedometer": None,
                "proximity": {"enabled": True},
                "device": sensorData.device,
                "camera": sensorData.camera
            });
        }

        async def checkCapabilities -> None {
            baro_ok = False;
            comp_ok = False;
            geo_ok = False;

            try {
                baro_avail = await CapacitorBarometer.isAvailable();
                baro_ok = baro_avail.isAvailable;
            } except Exception as e {
                baro_ok = False;
            }

            try {
                await CapgoCompass.getCurrentHeading();
                comp_ok = True;
            } except Exception as e {
                comp_ok = False;
            }

            try {
                perms = await Geolocation.checkPermissions();
                geo_ok = perms.location == "granted";
            } except Exception as e {
                geo_ok = False;
            }

            setCapabilities({
                "accelerometer": True,
                "gyroscope": True,
                "barometer": baro_ok,
                "compass": comp_ok,
                "geolocation": geo_ok,
                "proximity": True
            });
        }

        async def handleAction(action: dict) -> None {
            setDecisions(lambda prev: list -> list {
                return prev.slice(-9).concat([action]);
            });

            if action.type == "trigger" {
                try {
                    await Haptics.impact({"style": ImpactStyle.Heavy});
                } except Exception as e {
                    print("Haptics not available");
                }
            }

            if action.type == "trigger" and agentConfig.autoAct {
                await execute_action({
                    "type": "notify",
                    "value": action.message if action.message else "Action triggered"
                }, "agent");
            }
        }

        async def handleTakePhoto -> None {
            try {
                photo = await Camera.getPhoto({
                    "quality": 50,
                    "resultType": CameraResultType.Uri
                });
                if photo and photo.webPath {
                    setLastPhoto(photo.webPath);
                }
            } except Exception as e {
                ;
            }
        }

        def stopTracking -> None {
            # Set tracking flag to false - motion listener will check this
            isTrackingRef.current = False;

            # DO NOT remove motion listener - it breaks re-registration
            # The motion listener checks isTrackingRef.current before processing

            # Stop barometer
            baro_handle = barometerSubRef.current;
            barometerSubRef.current = None;
            if baro_handle {
                try {
                    baro_handle.remove();
                } except Exception as e {
                    ;
                }
            }
            CapacitorBarometer.stopMeasurementUpdates().catch(lambda -> None { ; });

            # Stop compass
            compass_handle = compassSubRef.current;
            compassSubRef.current = None;
            if compass_handle {
                try {
                    compass_handle.remove();
                } except Exception as e {
                    ;
                }
            }
            CapgoCompass.stopListening().catch(lambda -> None { ; });

            # Stop geolocation
            geo_id = geoWatchIdRef.current;
            geoWatchIdRef.current = None;
            if geo_id {
                Geolocation.clearWatch({"id": geo_id}).catch(
                    lambda -> None { ; }
                );
            }

            # Stop motion interval (but keep motion listener alive)
            if motionIntervalRef.current {
                clearInterval(motionIntervalRef.current);
                motionIntervalRef.current = None;
            }

            # Stop decision loop
            if decisionLoopRef.current {
                clearInterval(decisionLoopRef.current);
                decisionLoopRef.current = None;
            }

            setAgentRunning(False);
            setIsTracking(False);
            motionRef.current = None;
            barometerRef.current = None;
            compassRef.current = None;
            geolocationRef.current = None;
        }

        def startDecisionLoop -> None {
            if decisionLoopRef.current {
                clearInterval(decisionLoopRef.current);
            }

            decisionLoopRef.current = setInterval(
                lambda -> None {
                    async def runDecision -> None {
                        if not lastMotionRef.current {
                            return;
                        }

                        memory_query = "user:" + userIdRef.current + " motion routine geofence patterns";
                        memory_result = await backboard_read(memory_query);
                        memory_count = memory_result.memories.length if memory_result and memory_result.memories else 0;

                        decision = await decide_motion_with_walker(
                            lastMotionRef.current,
                            agentConfig,
                            True
                        );

                        if decision and memory_count > 0 {
                            decision.message = decision.message + " | memory hits: " + String(memory_count);
                            decision.source = "memory+walker";
                        }

                        if decision.priority > 0 {
                            await handleAction(decision);
                        }
                        await evaluate_rules_and_act(lastMotionRef.current, "decision-loop");

                        if decision and decision.priority > 0 {
                            await backboard_write(
                                "ritual_patterns",
                                "user:" + userIdRef.current + " decision-loop action=" + decision.type + " priority=" + String(decision.priority),
                                {
                                    "signal": "decision_loop",
                                    "source": "walker"
                                }
                            );
                        }
                    }
                    runDecision();
                },
                agentConfig.decisionInterval
            );
        }

        async def startTracking -> None {
            print("startTracking called!");
            
            # Set tracking flag FIRST so listener callbacks will process events
            isTrackingRef.current = True;

            try {
                await Geolocation.requestPermissions();
            } except Exception as e {
                ;
            }

            try {
                if DeviceMotionEvent and DeviceMotionEvent.requestPermission {
                    motion_perm = await DeviceMotionEvent.requestPermission();
                    print("DeviceMotion permission", motion_perm);
                }
            } except Exception as e {
                print("DeviceMotion permission request skipped", e);
            }

            try {
                if DeviceOrientationEvent and DeviceOrientationEvent.requestPermission {
                    orientation_perm = await DeviceOrientationEvent.requestPermission();
                    print("DeviceOrientation permission", orientation_perm);
                }
            } except Exception as e {
                print("DeviceOrientation permission request skipped", e);
            }

            startDecisionLoop();
            setAgentRunning(True);

            # Start demo timer - 6 seconds then emergency call
            start_demo_timer();

            setSensorData({
                "motion": None,
                "barometer": None,
                "compass": None,
                "geolocation": None,
                "pedometer": None,
                "proximity": {"enabled": True},
                "device": None,
                "camera": None
            });

            Device.getInfo().then(
                lambda info: Any -> None {
                    setSensorData(lambda prev: Any -> Any {
                        next_state = Object.assign({}, prev);
                        next_state.device = info;
                        return next_state;
                    });
                }
            ).catch(lambda -> None { ; });

            motionIntervalRef.current = setInterval(
                lambda -> None {
                    if motionRef.current and isTrackingRef.current {
                        emit_data();
                    }
                },
                200
            );

            # Attach motion listener if not already attached
            # On iOS, the auto-start in useEffect may have failed, so we try again here
            # after requesting permissions (user gesture)
            attachMotionListener();

            CapacitorBarometer.startMeasurementUpdates().then(
                lambda -> None {
                    CapacitorBarometer.addListener(
                        "measurement",
                        lambda event: Any -> None {
                            barometerRef.current = {
                                "pressure": event.pressure,
                                "relativeAltitude": event.relativeAltitude
                            };
                            emit_data();
                        }
                    ).then(lambda handle: Any -> None {
                        barometerSubRef.current = handle;
                    });
                }
            ).catch(lambda -> None { ; });

            CapgoCompass.startListening().then(
                lambda -> None {
                    CapgoCompass.addListener(
                        "headingChange",
                        lambda event: Any -> None {
                            compassRef.current = {"heading": event.value};
                            emit_data();
                        }
                    ).then(lambda handle: Any -> None {
                        compassSubRef.current = handle;
                    });
                }
            ).catch(lambda -> None { ; });

            Geolocation.getCurrentPosition().then(
                lambda pos: Any -> None {
                    if pos and pos.coords {
                        geolocationRef.current = {
                            "lat": HARDCODED_LAT,
                            "lng": HARDCODED_LNG,
                            "alt": pos.coords.altitude if pos.coords.altitude else 0,
                            "speed": pos.coords.speed if pos.coords.speed else 0,
                            "accuracy": pos.coords.accuracy if pos.coords.accuracy else 0
                        };
                        detect_geofence_exit(geolocationRef.current);
                        emit_data();
                        fetch_weather(HARDCODED_LAT, HARDCODED_LNG).then(
                            lambda w: Any -> None {
                                if w and w.ok {
                                    setWeatherData(w);
                                }
                            }
                        );
                    }
                }
            ).catch(lambda -> None { ; });

            Geolocation.watchPosition(
                {"enableHighAccuracy": True},
                lambda pos: Any -> None {
                    if pos and pos.coords {
                        geolocationRef.current = {
                            "lat": HARDCODED_LAT,
                            "lng": HARDCODED_LNG,
                            "alt": pos.coords.altitude if pos.coords.altitude else 0,
                            "speed": pos.coords.speed if pos.coords.speed else 0,
                            "accuracy": pos.coords.accuracy if pos.coords.accuracy else 0
                        };
                        detect_geofence_exit(geolocationRef.current);
                        emit_data();
                        fetch_weather(HARDCODED_LAT, HARDCODED_LNG).then(
                            lambda w: Any -> None {
                                if w and w.ok {
                                    setWeatherData(w);
                                }
                            }
                        );
                    }
                }
            ).then(lambda id: Any -> None {
                geoWatchIdRef.current = id;
            }).catch(lambda -> None { ; });

            setIsTracking(True);
        }

        async def handleMicToggle -> None {
            if isRecording {
                file = await Microphone.stopRecording().catch(
                    lambda -> Any { return None; }
                );
                setIsRecording(False);
                if file {
                    secs = Math.round(file.duration / 1000);
                    alert(
                        "Saved!\nDuration: " + String(secs)
                        + "s\nPath: " + (file.path if file.path else "in memory")
                    );
                } else {
                    alert("Recording failed");
                }
                return;
            }

            perms = await Microphone.requestPermissions().catch(
                lambda -> Any { return None; }
            );
            if not perms or perms.microphone != "granted" {
                alert("Permission denied");
                return;
            }

            started = await Microphone.startRecording().then(
                lambda -> Any { return True; }
            ).catch(lambda -> Any { return False; });

            setIsRecording(started);
            if not started {
                alert("Permission denied");
            }
        }

        def attachMotionListener -> None {
            # Attach motion listener for fall detection and agent processing
            # This is called once and the listener runs continuously
            
            if motionListenerAttached.current {
                print("Motion listener already attached");
                return;
            }
            
            print("Attaching motion listener");
            
            Motion.addListener(
                "accel",
                lambda event: Any -> None {
                    ax = 0;
                    ay = 0;
                    az = 0;
                    alpha = 0;
                    beta = 0;
                    gamma = 0;

                    if event and event.acceleration {
                        ax = event.acceleration.x if event.acceleration.x else 0;
                        ay = event.acceleration.y if event.acceleration.y else 0;
                        az = event.acceleration.z if event.acceleration.z else 0;
                    }
                    if event and event.rotationRate {
                        alpha = event.rotationRate.alpha if event.rotationRate.alpha else 0;
                        beta = event.rotationRate.beta if event.rotationRate.beta else 0;
                        gamma = event.rotationRate.gamma if event.rotationRate.gamma else 0;
                    }

                    if event and event.accelerationIncludingGravity and (
                        ax == 0 and ay == 0 and az == 0
                    ) {
                        ax = event.accelerationIncludingGravity.x if event.accelerationIncludingGravity.x else 0;
                        ay = event.accelerationIncludingGravity.y if event.accelerationIncludingGravity.y else 0;
                        az = event.accelerationIncludingGravity.z if event.accelerationIncludingGravity.z else 0;
                    }

                    # ALWAYS process fall detection regardless of agent state
                    detect_fall(ax, ay, az, alpha, beta, gamma);
                    
                    # Update motion ref and UI only if agent is tracking
                    if isTrackingRef.current {
                        motionRef.current = {
                            "acceleration": {
                                "x": ax,
                                "y": ay,
                                "z": az
                            },
                            "rotationRate": {
                                "alpha": alpha,
                                "beta": beta,
                                "gamma": gamma
                            },
                            "timestamp": Date.now()
                        };
                        lastMotionRef.current = motionRef.current;
                        
                        emit_data();
                        
                        decide_motion_with_walker(
                            motionRef.current,
                            agentConfig,
                            False
                        ).then(
                            lambda localDecision: Any -> None {
                                if localDecision and localDecision.priority > 0 {
                                    handleAction(localDecision);
                                }
                                evaluate_rules_and_act(motionRef.current, "live");
                            }
                        ).catch(lambda -> None { ; });
                    }
                }
            ).then(
                lambda handle: Any -> None {
                    accelSubRef.current = handle;
                    motionListenerAttached.current = True;
                    fallDetectionStarted.current = True;
                    print("Motion listener attached successfully");
                }
            ).catch(
                lambda e: Any -> None {
                    print("Motion listener error", e);
                }
            );
        }

        useEffect(
            lambda -> None {
                checkCapabilities();
                fetch_weather(HARDCODED_LAT, HARDCODED_LNG).then(
                    lambda w: Any -> None {
                        if w and w.ok {
                            setWeatherData(w);
                        }
                    }
                );
                
                # Auto-start motion listener on app mount for fall detection
                # This may fail on iOS without user gesture, but will work on Android
                attachMotionListener();
                
                return (lambda -> None {
                    if predictionAnimRef.current {
                        clearInterval(predictionAnimRef.current);
                        predictionAnimRef.current = None;
                    }
                    stopTracking();
                });
            },
            []
        );

        motionAccelView = None;
        motionGyroView = None;
        if sensorData.motion {
            motionAccelView =
                <div style={{"display": "flex", "gap": "16px"}}>
                    <div style={{"flex": "1"}}>
                        <label style={{"fontSize": "10px", "color": "var(--hj-text-muted)", "fontFamily": "var(--hj-font-mono)", "letterSpacing": "0.06em"}}>X</label>
                        <div style={{"color": "var(--hj-text)", "fontFamily": "var(--hj-font-mono)", "fontSize": "14px", "fontWeight": "400", "marginTop": "2px"}}>{sensorData.motion.acceleration.x.toFixed(2)}</div>
                    </div>
                    <div style={{"flex": "1"}}>
                        <label style={{"fontSize": "10px", "color": "var(--hj-text-muted)", "fontFamily": "var(--hj-font-mono)", "letterSpacing": "0.06em"}}>Y</label>
                        <div style={{"color": "var(--hj-text)", "fontFamily": "var(--hj-font-mono)", "fontSize": "14px", "fontWeight": "400", "marginTop": "2px"}}>{sensorData.motion.acceleration.y.toFixed(2)}</div>
                    </div>
                    <div style={{"flex": "1"}}>
                        <label style={{"fontSize": "10px", "color": "var(--hj-text-muted)", "fontFamily": "var(--hj-font-mono)", "letterSpacing": "0.06em"}}>Z</label>
                        <div style={{"color": "var(--hj-text)", "fontFamily": "var(--hj-font-mono)", "fontSize": "14px", "fontWeight": "400", "marginTop": "2px"}}>{sensorData.motion.acceleration.z.toFixed(2)}</div>
                    </div>
                </div>;

            motionGyroView =
                <div style={{"display": "flex", "gap": "16px", "marginTop": "12px", "paddingTop": "12px", "borderTop": "1px solid var(--hj-border)"}}>
                    <div style={{"flex": "1"}}>
                        <label style={{"fontSize": "10px", "color": "var(--hj-text-muted)", "fontFamily": "var(--hj-font-mono)"}}>α</label>
                        <div style={{"color": "var(--hj-text)", "fontFamily": "var(--hj-font-mono)", "fontSize": "14px", "fontWeight": "400", "marginTop": "2px"}}>{sensorData.motion.rotationRate.alpha.toFixed(2)}</div>
                    </div>
                    <div style={{"flex": "1"}}>
                        <label style={{"fontSize": "10px", "color": "var(--hj-text-muted)", "fontFamily": "var(--hj-font-mono)"}}>β</label>
                        <div style={{"color": "var(--hj-text)", "fontFamily": "var(--hj-font-mono)", "fontSize": "14px", "fontWeight": "400", "marginTop": "2px"}}>{sensorData.motion.rotationRate.beta.toFixed(2)}</div>
                    </div>
                    <div style={{"flex": "1"}}>
                        <label style={{"fontSize": "10px", "color": "var(--hj-text-muted)", "fontFamily": "var(--hj-font-mono)"}}>γ</label>
                        <div style={{"color": "var(--hj-text)", "fontFamily": "var(--hj-font-mono)", "fontSize": "14px", "fontWeight": "400", "marginTop": "2px"}}>{sensorData.motion.rotationRate.gamma.toFixed(2)}</div>
                    </div>
                </div>;
        }

        compassView = None;
        if sensorData.compass {
            compassView =
                <div style={{"fontSize": "13px", "color": "var(--hj-text-secondary)", "fontFamily": "var(--hj-font-mono)"}}>
                    Heading: {sensorData.compass.heading.toFixed(1)}°
                </div>;
        }

        barometerView = None;
        if sensorData.barometer {
            barometerView =
                <div style={{"display": "flex", "gap": "20px", "fontSize": "13px", "color": "var(--hj-text-secondary)", "fontFamily": "var(--hj-font-mono)"}}>
                    <div>Pressure: {sensorData.barometer.pressure.toFixed(1)}</div>
                    <div>Alt: {sensorData.barometer.relativeAltitude.toFixed(1)}m</div>
                </div>;
        }

        geoView = None;
        if sensorData.geolocation {
            geoView =
                <div style={{"display": "grid", "gridTemplateColumns": "repeat(2, 1fr)", "gap": "10px", "fontSize": "12px", "color": "var(--hj-text-secondary)", "fontFamily": "var(--hj-font-mono)"}}>
                    <div>Lat: {sensorData.geolocation.lat.toFixed(6)}</div>
                    <div>Lng: {sensorData.geolocation.lng.toFixed(6)}</div>
                    <div>Alt: {sensorData.geolocation.alt.toFixed(1)}m</div>
                    <div>Speed: {sensorData.geolocation.speed.toFixed(1)}m/s</div>
                </div>;
        }

        deviceView = None;
        if sensorData.device {
            deviceView =
                <div style={{"fontSize": "12px", "color": "var(--hj-text-muted)", "fontFamily": "var(--hj-font-mono)"}}>
                    <div>{sensorData.device.model}</div>
                    <div>Android {sensorData.device.androidSDKVersion}</div>
                </div>;
        }

        decisionsView = None;
        if decisions.length == 0 {
            decisionsView =
                <p style={{"fontSize": "14px", "color": "var(--hj-text-muted)", "fontStyle": "italic"}}>
                    No decisions yet
                </p>;
        } else {
            decisionsView =
                <div style={{"display": "grid", "gap": "10px", "fontSize": "13px"}}>
                    <div style={{"color": "var(--hj-text-muted)", "fontFamily": "var(--hj-font-mono)", "fontSize": "10px", "letterSpacing": "0.04em"}}>Total: {decisions.length}</div>
                    <div style={{"color": "var(--hj-accent)", "lineHeight": "1.6"}}>
                        {decisions[decisions.length - 1].message}
                    </div>
                </div>;
        }

        # Fall detection countdown overlay
        fallOverlay = None;
        if fallCountdown > 0 {
            fall_lat = HARDCODED_LAT;
            fall_lng = HARDCODED_LNG;
            fallMapUrl = "https://www.openstreetmap.org/export/embed.html?bbox="
                + String(fall_lng - 0.01) + "," + String(fall_lat - 0.01) + ","
                + String(fall_lng + 0.01) + "," + String(fall_lat + 0.01)
                + "&layer=mapnik&marker=" + String(fall_lat) + "," + String(fall_lng);

            fallMapIframe = <iframe
                src={fallMapUrl}
                style={{
                    "width": "100%",
                    "maxWidth": "360px",
                    "height": "140px",
                    "border": "none",
                    "borderRadius": "18px",
                    "marginBottom": "28px",
                    "opacity": "0.9",
                    "animation": "hijac-fade-up 0.5s ease-out 0.2s both"
                }}
                loading="lazy"
            />;

            fallOverlay =
                <div style={{
                    "position": "fixed",
                    "top": "0",
                    "left": "0",
                    "right": "0",
                    "bottom": "0",
                    "background": "#FFFFFF",
                    "display": "flex",
                    "flexDirection": "column",
                    "alignItems": "center",
                    "justifyContent": "center",
                    "zIndex": "9999",
                    "color": "var(--hj-text)",
                    "padding": "24px",
                    "fontFamily": "var(--hj-font-body)"
                }}>
                    <div style={{
                        "width": "88px",
                        "height": "88px",
                        "borderRadius": "50%",
                        "border": "1.5px solid var(--hj-red-border)",
                        "display": "flex",
                        "alignItems": "center",
                        "justifyContent": "center",
                        "marginBottom": "20px",
                        "animation": "hijac-pulse-ring 2s ease-in-out infinite",
                        "background": "var(--hj-red-light)"
                    }}>
                        <div style={{
                            "fontSize": "40px",
                            "fontWeight": "300",
                            "color": "var(--hj-red)",
                            "fontFamily": "var(--hj-font-display)",
                            "animation": "hijac-countdown-pulse 1s ease-in-out infinite"
                        }}>
                            {fallCountdown}
                        </div>
                    </div>
                    <div style={{
                        "fontSize": "10px",
                        "fontWeight": "500",
                        "marginBottom": "8px",
                        "textAlign": "center",
                        "letterSpacing": "0.16em",
                        "textTransform": "uppercase",
                        "color": "var(--hj-red)",
                        "fontFamily": "var(--hj-font-mono)"
                    }}>
                        Fall Detected
                    </div>
                    <div style={{
                        "fontSize": "15px",
                        "marginBottom": "32px",
                        "textAlign": "center",
                        "maxWidth": "240px",
                        "lineHeight": "1.65",
                        "color": "var(--hj-text-secondary)"
                    }}>
                        Emergency call in {fallCountdown}s
                    </div>
                    {fallMapIframe}
                    <button
                        onClick={cancel_fall_countdown}
                        style={{
                            "padding": "14px 48px",
                            "fontSize": "14px",
                            "fontWeight": "500",
                            "background": "var(--hj-red-light)",
                            "color": "var(--hj-red)",
                            "border": "1px solid var(--hj-red-border)",
                            "borderRadius": "100px",
                            "cursor": "pointer",
                            "fontFamily": "var(--hj-font-body)",
                            "transition": "all 0.25s cubic-bezier(0.16,1,0.3,1)"
                        }}
                    >
                        I'm OK — Cancel
                    </button>
                    <div style={{
                        "marginTop": "24px",
                        "fontSize": "11px",
                        "color": "var(--hj-text-muted)",
                        "fontFamily": "var(--hj-font-mono)",
                        "letterSpacing": "0.02em"
                    }}>
                        Calling {emergency_contact_name()}
                    </div>
                </div>;
        }

        # Passcode challenge overlay (kidnap scenario)
        passcodeOverlay = None;
        if showPasscodeChallenge {
            lat = HARDCODED_LAT;
            lng = HARDCODED_LNG;
            mapUrl = "https://www.openstreetmap.org/export/embed.html?bbox="
                + String(lng - 0.01) + "," + String(lat - 0.01) + ","
                + String(lng + 0.01) + "," + String(lat + 0.01)
                + "&layer=mapnik&marker=" + String(lat) + "," + String(lng);
            
            weatherInfo = None;
            if weatherData and weatherData.ok {
                weatherInfo = <div style={{
                    "background": "var(--hj-amber-light)",
                    "padding": "10px 16px",
                    "borderRadius": "14px",
                    "fontSize": "11px",
                    "display": "flex",
                    "gap": "16px",
                    "flexWrap": "wrap",
                    "justifyContent": "center",
                    "color": "var(--hj-text-secondary)",
                    "fontFamily": "var(--hj-font-mono)",
                    "border": "1px solid var(--hj-amber-border)",
                    "letterSpacing": "0.02em"
                }}>
                    <span>{weatherData.description}</span>
                    <span>{Math.round(weatherData.temp)}°C</span>
                    <span>{weatherData.humidity}%</span>
                    <span>{Math.round(weatherData.wind_speed)} m/s</span>
                </div>;
            }
            
            mapIframe = <iframe
                src={mapUrl}
                style={{
                    "width": "100%",
                    "height": "140px",
                    "border": "none",
                    "borderRadius": "18px",
                    "marginBottom": "14px",
                    "animation": "hijac-fade-up 0.5s ease-out 0.2s both"
                }}
                loading="lazy"
            />;
            
            passcodeOverlay =
                <div style={{
                    "position": "fixed",
                    "top": "0",
                    "left": "0",
                    "right": "0",
                    "bottom": "0",
                    "background": "linear-gradient(160deg, #FDF8F0 0%, #FBF7F1 35%, var(--hj-bg) 100%)",
                    "display": "flex",
                    "flexDirection": "column",
                    "alignItems": "center",
                    "justifyContent": "center",
                    "zIndex": "9999",
                    "color": "var(--hj-text)",
                    "padding": "20px",
                    "overflow": "auto",
                    "fontFamily": "var(--hj-font-body)"
                }}>
                    <div style={{
                        "width": "72px",
                        "height": "72px",
                        "borderRadius": "50%",
                        "border": "1.5px solid var(--hj-amber-border)",
                        "display": "flex",
                        "alignItems": "center",
                        "justifyContent": "center",
                        "marginBottom": "16px",
                        "animation": "hijac-pulse-ring 2.5s ease-in-out infinite",
                        "background": "var(--hj-amber-light)"
                    }}>
                        <div style={{
                            "fontSize": "28px",
                            "fontWeight": "300",
                            "color": "var(--hj-amber)",
                            "fontFamily": "var(--hj-font-display)"
                        }}>
                            {passcodeCountdown}
                        </div>
                    </div>
                    <div style={{
                        "fontSize": "10px",
                        "fontWeight": "500",
                        "marginBottom": "8px",
                        "textAlign": "center",
                        "letterSpacing": "0.16em",
                        "textTransform": "uppercase",
                        "color": "var(--hj-amber)",
                        "fontFamily": "var(--hj-font-mono)"
                    }}>
                        Safety Check
                    </div>
                    <div style={{
                        "fontSize": "15px",
                        "marginBottom": "24px",
                        "textAlign": "center",
                        "maxWidth": "260px",
                        "lineHeight": "1.65",
                        "color": "var(--hj-text-secondary)"
                    }}>
                        Unusual activity detected. Enter your passcode.
                    </div>
                    
                    {mapIframe}
                    {weatherInfo}
                    
                    <input
                        type="password"
                        placeholder="Passcode"
                        value={passcodeInput}
                        onChange={lambda e: Any -> None {
                            setPasscodeInput(e.target.value);
                        }}
                        onKeyDown={lambda e: Any -> None {
                            if e.key == "Enter" {
                                verify_passcode(passcodeInput);
                            }
                        }}
                        style={{
                            "padding": "14px",
                            "fontSize": "20px",
                            "textAlign": "center",
                            "border": "1px solid var(--hj-amber-border)",
                            "borderRadius": "14px",
                            "width": "200px",
                            "marginTop": "18px",
                            "marginBottom": "14px",
                            "background": "var(--hj-amber-light)",
                            "color": "var(--hj-text)",
                            "outline": "none",
                            "fontFamily": "var(--hj-font-mono)",
                            "letterSpacing": "0.3em",
                            "transition": "border-color 0.25s ease"
                        }}
                        autoFocus={True}
                    />
                    {(
                        <div style={{
                            "color": "var(--hj-amber)",
                            "marginBottom": "12px",
                            "fontSize": "13px"
                        }}>
                            {passcodeError}
                        </div>
                    ) if passcodeError else None}
                    <button
                        onClick={lambda -> None { verify_passcode(passcodeInput); }}
                        style={{
                            "padding": "12px 48px",
                            "fontSize": "14px",
                            "fontWeight": "500",
                            "background": "var(--hj-amber-light)",
                            "color": "var(--hj-amber)",
                            "border": "1px solid var(--hj-amber-border)",
                            "borderRadius": "100px",
                            "cursor": "pointer",
                            "marginBottom": "8px",
                            "fontFamily": "var(--hj-font-body)",
                            "transition": "all 0.25s cubic-bezier(0.16,1,0.3,1)"
                        }}
                    >
                        Verify
                    </button>
                    <div style={{
                        "marginTop": "14px",
                        "fontSize": "11px",
                        "color": "var(--hj-text-muted)",
                        "textAlign": "center",
                        "fontFamily": "var(--hj-font-mono)",
                        "letterSpacing": "0.02em"
                    }}>
                        Emergency call if not verified
                    </div>
                </div>;
        }

        # Demo timer overlay (Start Agent button) - only show last 3 seconds
        demoTimerOverlay = None;
        if demoCountdown > 0 and demoCountdown <= 3 {
            demoTimerOverlay =
                <div style={{
                    "position": "fixed",
                    "top": "0",
                    "left": "0",
                    "right": "0",
                    "bottom": "0",
                    "background": "linear-gradient(160deg, #F0F5F4 0%, #F2F6F5 35%, var(--hj-bg) 100%)",
                    "display": "flex",
                    "flexDirection": "column",
                    "alignItems": "center",
                    "justifyContent": "center",
                    "zIndex": "9999",
                    "color": "var(--hj-text)",
                    "padding": "24px",
                    "fontFamily": "var(--hj-font-body)"
                }}>
                    <div style={{
                        "width": "104px",
                        "height": "104px",
                        "borderRadius": "50%",
                        "border": "1.5px solid var(--hj-accent-border)",
                        "display": "flex",
                        "alignItems": "center",
                        "justifyContent": "center",
                        "marginBottom": "24px",
                        "animation": "hijac-pulse-ring 1.5s ease-in-out infinite",
                        "background": "var(--hj-accent-light)"
                    }}>
                        <div style={{
                            "fontSize": "48px",
                            "fontWeight": "300",
                            "color": "var(--hj-accent)",
                            "fontFamily": "var(--hj-font-display)",
                            "animation": "hijac-countdown-pulse 1s ease-in-out infinite"
                        }}>
                            {demoCountdown}
                        </div>
                    </div>
                    <div style={{
                        "fontSize": "10px",
                        "fontWeight": "500",
                        "marginBottom": "8px",
                        "textAlign": "center",
                        "letterSpacing": "0.16em",
                        "textTransform": "uppercase",
                        "color": "var(--hj-accent)",
                        "fontFamily": "var(--hj-font-mono)"
                    }}>
                        Demo Mode
                    </div>
                    <div style={{
                        "fontSize": "15px",
                        "marginBottom": "36px",
                        "textAlign": "center",
                        "maxWidth": "240px",
                        "lineHeight": "1.65",
                        "color": "var(--hj-text-secondary)"
                    }}>
                        Calling {emergency_contact_name()} in {demoCountdown}s
                    </div>
                    <button
                        onClick={cancel_demo_timer}
                        style={{
                            "padding": "14px 48px",
                            "fontSize": "14px",
                            "fontWeight": "500",
                            "background": "var(--hj-accent-light)",
                            "color": "var(--hj-accent)",
                            "border": "1px solid var(--hj-accent-border)",
                            "borderRadius": "100px",
                            "cursor": "pointer",
                            "fontFamily": "var(--hj-font-body)",
                            "transition": "all 0.25s cubic-bezier(0.16,1,0.3,1)"
                        }}
                    >
                        Cancel
                    </button>
                    <div style={{
                        "marginTop": "24px",
                        "fontSize": "11px",
                        "color": "var(--hj-text-muted)",
                        "fontFamily": "var(--hj-font-mono)",
                        "letterSpacing": "0.02em"
                    }}>
                        {emergency_contact()}
                    </div>
                </div>;
        }

        statusClass = "var(--hj-green)" if workflowCreated else "var(--hj-text-muted)";

        # --- card base style ---
        glassCard = {
            "marginBottom": "16px",
            "padding": "0px 24px",
            "borderRadius": "20px",
            "background": "var(--hj-surface)",
            "border": "1px solid var(--hj-border)",
            "boxShadow": "var(--hj-shadow-md)",
            "animation": "hijac-fade-up 0.5s ease-out both"
        };

        predictionCard =
            <div style={Object.assign({}, glassCard, {
                "fontSize": "14px",
                "color": "var(--hj-text-secondary)",
                "lineHeight": "1.6"
            })}>
                
            </div>;
        if isPredictingDestination {
            dots = "." * ((predictionLoadingStep % 3) + 1);
            loadingText = "Predicting" + dots;
            predictionCard =
                <div style={Object.assign({}, glassCard, {"animation": "hijac-glow 3s ease-in-out infinite, hijac-fade-up 0.5s ease-out both"})}>
                    <div style={{"fontSize": "9px", "color": "var(--hj-text-muted)", "marginBottom": "10px", "fontWeight": "500", "textTransform": "uppercase", "letterSpacing": "0.16em", "fontFamily": "var(--hj-font-mono)"}}>
                        Meal Predictor
                    </div>
                    <div style={{"fontSize": "18px", "fontWeight": "500", "color": "var(--hj-accent)", "letterSpacing": "-0.02em", "animation": "hijac-breathe 1.5s ease-in-out infinite", "fontFamily": "var(--hj-font-display)"}}>
                        {loadingText}
                    </div>
                    <div style={{"fontSize": "11px", "color": "var(--hj-text-muted)", "marginTop": "10px", "fontFamily": "var(--hj-font-mono)"}}>
                        {predictionLoadingLocation}
                    </div>
                </div>;
        } elif eatingPrediction {
            confidenceColor = "var(--hj-green)" if eatingPrediction.confidence_pct >= 70 else ("var(--hj-amber)" if eatingPrediction.confidence_pct >= 45 else "var(--hj-red)");
            confidenceBg = "var(--hj-green-light)" if eatingPrediction.confidence_pct >= 70 else ("var(--hj-amber-light)" if eatingPrediction.confidence_pct >= 45 else "var(--hj-red-light)");
            orderStatusView = None;
                            if mealOrderStatus and mealOrderStatus.trim().length > 0 {
                                orderStatusView =
                                    <div style={{
                                        "fontSize": "13px",
                                        "color": "var(--hj-accent)",
                        "marginTop": "16px",
                        "paddingTop": "16px",
                                        "borderTop": "1px solid var(--hj-border)",
                                        "lineHeight": "1.6"
                                    }}>
                                        {mealOrderStatus}
                                    </div>;
                            }
            replayVoiceButton = None;
            if showVoiceReplay {
                replayVoiceButton =
                    <button
                        onClick={lambda -> None {
                            unlock_audio_output();
                            speak_assistant_prompt("do you wnat to place your usual order?");
                        }}
                        style={{
                            "marginTop": "12px",
                            "padding": "9px 20px",
                            "fontSize": "13px",
                            "fontWeight": "500",
                            "borderRadius": "100px",
                            "border": "1px solid var(--hj-accent-border)",
                            "background": "var(--hj-accent-light)",
                            "color": "var(--hj-accent)",
                            "cursor": "pointer",
                            "fontFamily": "var(--hj-font-body)",
                            "transition": "all 0.25s cubic-bezier(0.16,1,0.3,1)"
                        }}
                    >
                        Tap to hear voice prompt
                    </button>;
            }
            smsFallbackButton = None;
            if showSmsFallbackButton {
                smsFallbackButton =
                    <button
                        onClick={open_sms_fallback}
                        style={{
                            "marginTop": "12px",
                            "padding": "10px 16px",
                            "fontSize": "12px",
                            "fontWeight": "600",
                            "borderRadius": "10px",
                            "border": "1px solid var(--hj-amber-border)",
                            "background": "var(--hj-amber-light)",
                            "color": "var(--hj-amber)",
                            "cursor": "pointer",
                            "fontFamily": "var(--hj-font-body)"
                        }}
                    >
                        Open Messages
                    </button>;
            }
            testAudioButton =
                <button
                    onClick={test_local_audio}
                    style={{
                        "marginTop": "12px",
                        "padding": "8px 14px",
                        "fontSize": "11px",
                        "fontWeight": "600",
                        "borderRadius": "8px",
                        "border": "1px solid var(--hj-border)",
                        "background": "var(--hj-surface-raised)",
                        "color": "var(--hj-text)",
                        "cursor": "pointer"
                    }}
                >
                    Test Local Audio
                </button>;
            ttsErrorView = None;
            if lastTtsError and lastTtsError.trim().length > 0 {
                ttsErrorView =
                    <div style={{"fontSize": "11px", "color": "var(--hj-red)", "marginTop": "8px", "fontFamily": "var(--hj-font-mono)"}}>
                        TTS: {lastTtsError}
                    </div>;
            }
            voiceInputView = None;
            if showVoiceInputUi {
                listeningDots = "." * (((4 - voiceInputSecondsLeft) % 3) + 1);
                voiceInputView =
                    <div style={{
                        "marginTop": "14px",
                        "padding": "14px 16px",
                        "borderRadius": "14px",
                        "background": "var(--hj-accent-light)",
                        "border": "1px solid var(--hj-accent-border)"
                    }}>
                        <div style={{"fontSize": "9px", "color": "var(--hj-accent)", "fontWeight": "500", "textTransform": "uppercase", "letterSpacing": "0.16em", "fontFamily": "var(--hj-font-mono)"}}>
                            Voice Input
                        </div>
                        <div style={{"fontSize": "15px", "fontWeight": "500", "color": "var(--hj-accent)", "marginTop": "6px"}}>
                            Listening{listeningDots}
                        </div>
                        <div style={{"fontSize": "11px", "color": "var(--hj-text-secondary)", "marginTop": "6px", "fontFamily": "var(--hj-font-mono)"}}>
                            Heard: "Yes" ({String(voiceInputSecondsLeft)}s)
                        </div>
                    </div>;
            }
            predictionCard =
                <div style={Object.assign({}, glassCard)}>
                    <div style={{"fontSize": "9px", "color": "var(--hj-text-muted)", "marginBottom": "12px", "fontWeight": "500", "textTransform": "uppercase", "letterSpacing": "0.16em", "fontFamily": "var(--hj-font-mono)"}}>
                        Next Destination
                    </div>
                    <div style={{"display": "flex", "justifyContent": "space-between", "gap": "16px", "alignItems": "baseline"}}>
                        <div style={{
                            "fontSize": "28px",
                            "fontWeight": "400",
                            "color": "var(--hj-text)",
                            "letterSpacing": "-0.03em",
                            "fontFamily": "var(--hj-font-display)",
                            "lineHeight": "1.2"
                        }}>
                            {eatingPrediction.destination_name}
                        </div>
                        <div style={{
                            "fontSize": "12px",
                            "fontWeight": "500",
                            "color": confidenceColor,
                            "padding": "5px 12px",
                            "background": confidenceBg,
                            "borderRadius": "100px",
                            "fontFamily": "var(--hj-font-mono)",
                            "whiteSpace": "nowrap",
                            "flexShrink": "0"
                        }}>
                            {String(eatingPrediction.confidence_pct)}%
                        </div>
                    </div>
                    <div style={{"fontSize": "14px", "color": "var(--hj-text-secondary)", "marginTop": "10px", "lineHeight": "1.6"}}>
                        {eatingPrediction.reason if eatingPrediction.reason else "Estimated from time/day context"}
                    </div>
                    <div style={{"fontSize": "10px", "color": "var(--hj-text-muted)", "marginTop": "12px", "fontFamily": "var(--hj-font-mono)", "letterSpacing": "0.02em"}}>
                        Voice via local bundled assets
                    </div>
                    {ttsErrorView}
                    {orderStatusView}
                    {voiceInputView}
                    {replayVoiceButton}
                    {smsFallbackButton}
                </div>;
        }

        predictionErrorView = None;
        if eatingPredictionError {
            predictionErrorView =
                <div style={{
                    "marginBottom": "16px",
                    "padding": "14px 18px",
                    "fontSize": "13px",
                    "borderRadius": "14px",
                    "background": "var(--hj-red-light)",
                    "color": "var(--hj-red)",
                    "borderLeft": "3px solid var(--hj-red-border)",
                    "lineHeight": "1.6",
                    "animation": "hijac-fade-up 0.3s ease-out both"
                }}>
                    {eatingPredictionError}
                </div>;
        }

        ttsCard =
            <div style={Object.assign({}, glassCard)}>
                <div style={{"fontSize": "9px", "color": "var(--hj-text-muted)", "marginBottom": "14px", "fontWeight": "500", "textTransform": "uppercase", "letterSpacing": "0.16em", "fontFamily": "var(--hj-font-mono)"}}>
                    Text-to-Speech
                </div>
                <textarea
                    placeholder="Enter text to speak..."
                    value={ttsText}
                    onChange={lambda e: Any -> None {
                        setTtsText(e.target.value);
                    }}
                    disabled={ttsLoading or ttsPlaying}
                    style={{
                        "width": "100%",
                        "minHeight": "80px",
                        "padding": "16px",
                        "borderRadius": "14px",
                        "border": "1px solid var(--hj-border)",
                        "background": "var(--hj-surface-raised)",
                        "color": "var(--hj-text)",
                        "fontSize": "14px",
                        "resize": "vertical",
                        "fontFamily": "var(--hj-font-body)",
                        "marginBottom": "14px",
                        "boxSizing": "border-box",
                        "outline": "none",
                        "lineHeight": "1.7",
                        "transition": "border-color 0.25s ease"
                    }}
                />
                <div style={{"display": "flex", "gap": "10px"}}>
                    <button
                        onClick={play_tts}
                        disabled={ttsLoading or ttsPlaying or not ttsText or ttsText.trim().length == 0}
                        style={{
                            "flex": "1",
                            "padding": "11px 18px",
                            "fontSize": "13px",
                            "fontWeight": "500",
                            "borderRadius": "100px",
                            "border": "none",
                            "background": "var(--hj-accent)" if not ttsLoading and not ttsPlaying else "var(--hj-surface-raised)",
                            "color": "#FFFFFF" if not ttsLoading and not ttsPlaying else "var(--hj-text-muted)",
                            "cursor": "pointer" if not ttsLoading and not ttsPlaying else "wait",
                            "fontFamily": "var(--hj-font-body)",
                            "transition": "all 0.25s cubic-bezier(0.16,1,0.3,1)"
                        }}
                    >
                        {"Loading..." if ttsLoading else ("Playing..." if ttsPlaying else "Speak")}
                    </button>
                    <button
                        onClick={stop_tts}
                        disabled={not ttsPlaying}
                        style={{
                            "padding": "11px 18px",
                            "fontSize": "13px",
                            "fontWeight": "500",
                            "borderRadius": "100px",
                            "border": "1px solid var(--hj-border-strong)",
                            "background": "transparent",
                            "color": "var(--hj-text-secondary)" if ttsPlaying else "var(--hj-text-muted)",
                            "cursor": "pointer" if ttsPlaying else "not-allowed",
                            "fontFamily": "var(--hj-font-body)",
                            "transition": "all 0.25s ease"
                        }}
                    >
                        Stop
                    </button>
                </div>
            </div>;

        return
            <div style={{
                "width": "100%",
                "maxWidth": "100vw",
                "overflowX": "hidden",
                "padding": "0",
                "minHeight": "100vh",
                "background": "var(--hj-bg)",
                "color": "var(--hj-text)",
                "fontFamily": "var(--hj-font-body)",
                "boxSizing": "border-box",
                "display": "flex",
                "flexDirection": "column",
                "WebkitFontSmoothing": "antialiased"
            }}>
                <header style={{
                    "display": "flex",
                    "justifyContent": "space-between",
                    "alignItems": "center",
                    "padding": "20px 24px",
                    "background": "rgba(250,248,245,0.92)",
                    "borderBottom": "1px solid var(--hj-border)",
                    "backdropFilter": "blur(24px)",
                    "WebkitBackdropFilter": "blur(24px)",
                    "position": "sticky",
                    "top": "0",
                    "zIndex": "100",
                    "animation": "hijac-fade-in 0.6s ease-out both"
                }}>
                    <div style={{"display": "flex", "alignItems": "baseline", "gap": "12px"}}>
                        <h1 style={{
                            "fontSize": "26px",
                            "margin": "0",
                            "fontWeight": "500",
                            "letterSpacing": "-0.04em",
                            "color": "var(--hj-text)",
                            "fontFamily": "var(--hj-font-display)",
                            "fontStyle": "italic"
                        }}>Hijac</h1>
                        <div style={{
                            "width": "6px",
                            "height": "6px",
                            "borderRadius": "50%",
                            "background": "var(--hj-accent)" if workflowCreated else "var(--hj-text-muted)",
                            "boxShadow": "0 0 10px rgba(26,92,82,0.3)" if workflowCreated else "none",
                            "transition": "all 0.4s cubic-bezier(0.16,1,0.3,1)",
                            "flexShrink": "0",
                            "position": "relative",
                            "top": "-1px"
                        }}/>
                    </div>
                    <div style={{"display": "flex", "alignItems": "center", "gap": "12px"}}>
                        <button
                            onClick={predict_next_eating_destination}
                            disabled={isPredictingDestination}
                            style={{
                                "padding": "8px 18px",
                                "fontSize": "12px",
                                "fontWeight": "500",
                                "borderRadius": "100px",
                                "border": "1px solid var(--hj-accent-border)",
                                "background": "var(--hj-accent-light)",
                                "color": "var(--hj-accent)",
                                "cursor": "wait" if isPredictingDestination else "pointer",
                                "opacity": 0.5 if isPredictingDestination else 1,
                                "whiteSpace": "nowrap",
                                "fontFamily": "var(--hj-font-body)",
                                "transition": "all 0.25s cubic-bezier(0.16,1,0.3,1)",
                                "letterSpacing": "0.01em"
                            }}
                        >
                            {"Predicting..." if isPredictingDestination else "v"}
                        </button>
                        <span style={{
                            "fontSize": "9px",
                            "fontWeight": "500",
                            "padding": "4px 10px",
                            "borderRadius": "100px",
                            "background": "var(--hj-green-light)" if workflowCreated else "var(--hj-surface-raised)",
                            "color": "var(--hj-green)" if workflowCreated else "var(--hj-text-muted)",
                            "fontFamily": "var(--hj-font-mono)",
                            "letterSpacing": "0.08em",
                            "textTransform": "uppercase",
                            "transition": "all 0.3s ease"
                        }}>
                            {"Active" if workflowCreated else ""}
                        </span>
                    </div>
                </header>

                <main style={{
                    "flex": "1",
                    "display": "flex",
                    "flexDirection": "column",
                    "justifyContent": "center",
                    "width": "360px",
                    "margin": "0 auto",
                    "padding": "32px 24px 48px 24px"
                }}>
                    {predictionErrorView}
                    {predictionCard}
                    {(
                        <div style={{
                            "textAlign": "center",
                            "padding": "0 24px",
                            "animation": "hijac-fade-up 0.4s ease-out both"
                        }}>
                            <div style={{
                                "width": "44px",
                                "height": "44px",
                                "margin": "0 auto 24px auto",
                                "borderRadius": "50%",
                                "border": "2px solid var(--hj-accent-border)",
                                "borderTopColor": "var(--hj-accent)",
                                "animation": "hijac-spin 0.9s linear infinite"
                            }} />
                            <p style={{
                                "fontSize": "14px",
                                "color": "var(--hj-text-secondary)",
                                "margin": "0",
                                "fontWeight": "400",
                                "fontFamily": "var(--hj-font-body)",
                                "letterSpacing": "0.01em"
                            }}>
                                Creating workflow...
                            </p>
                        </div>
                    ) if isCreatingWorkflow else (
                        <div style={{
                            "display": "flex",
                            "flexDirection": "column",
                            "alignItems": "center",
                            "animation": "hijac-fade-up 0.5s ease-out 0.1s both"
                        }}>
                            <div style={{
                                "textAlign": "center",
                                "marginBottom": "32px"
                            }}>
                                <h2 style={{
                                    "fontSize": "36px",
                                    "color": "var(--hj-text)",
                                    "margin": "0 0 12px 0",
                                    "fontWeight": "400",
                                    "letterSpacing": "-0.03em",
                                    "fontFamily": "var(--hj-font-display)"
                                }}>
                                    Hijac your day!
                                </h2>
                            </div>

                            <div style={{
                                "width": "100%",
                                "borderRadius": "20px",
                                "border": "2px solid var(--hj-border-strong)",
                                "background": "var(--hj-surface)",
                                "overflow": "hidden",
                                "display": "flex",
                                "flexDirection": "column",
                                "boxShadow": "var(--hj-shadow-lg)",
                                "transition": "border-color 0.3s ease, box-shadow 0.3s ease",
                                "animation": "hijac-fade-up 0.5s ease-out 0.2s both"
                            }}>
                                <textarea
                                    placeholder="e.g. Monitor for falls and alert emergency contacts"
                                    value={workflowPrompt}
                                    onChange={lambda e: Any -> None {
                                        setWorkflowPrompt(e.target.value);
                                    }}
                                    style={{
                                        "minHeight": "140px",
                                        "padding": "20px 22px",
                                        "border": "2px solid #78716C",
                                        "borderRadius": "12px",
                                        "margin": "16px",
                                        "background": "#FFFFFF",
                                        "color": "#1C1917",
                                        "fontSize": "15px",
                                        "lineHeight": "1.75",
                                        "resize": "none",
                                        "fontFamily": "var(--hj-font-body)",
                                        "outline": "none",
                                        "width": "calc(100% - 32px)",
                                        "boxSizing": "border-box",
                                        "fontWeight": "400"
                                    }}
                                />
                                <div style={{
                                    "padding": "16px 20px",
                                    "borderTop": "1px solid #E5E5E5",
                                    "display": "flex",
                                    "justifyContent": "flex-end",
                                    "alignItems": "center",
                                }}>
                                    <button
                                        onClick={create_workflow}
                                        style={{
                                            "padding": "14px 32px",
                                            "border": "none",
                                            "borderRadius": "12px",
                                            "fontSize": "16px",
                                            "fontWeight": "600",
                                            "cursor": "pointer",
                                            "background": "#1A5C52",
                                            "color": "#FFFFFF",
                                            "fontFamily": "var(--hj-font-body)",
                                            "transition": "all 0.25s cubic-bezier(0.16,1,0.3,1)",
                                            "letterSpacing": "0.01em",
                                            "boxShadow": "0 4px 12px rgba(26,92,82,0.3)"
                                        }}
                                    >
                                        Submit
                                    </button>
                                </div>
                            </div>
                        </div>
                    )}
                </main>
                {fallOverlay}
                {passcodeOverlay}
                {demoTimerOverlay}
            </div>;
    }
}
