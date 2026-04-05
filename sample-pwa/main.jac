"""Sensor Agent app ported from the sensor-agent project."""

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

    def fall_detection_thresholds -> dict {
        return {
            "impact_accel_norm": 25.0,  # m/s² (3G+)
            "stillness_gyro_norm": 0.1,  # rad/s
            "stillness_duration_ms": 3000,  # 3 seconds of stillness
            "orientation_change_deg": 60.0,  # degrees from upright
            "confidence_threshold": 0.90,
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
            mock_motion = {
                "acceleration": {
                    "x": 7.2,
                    "y": 5.1,
                    "z": 9.4
                },
                "rotationRate": {
                    "alpha": 35.0,
                    "beta": 18.0,
                    "gamma": 11.0
                },
                "timestamp": Date.now()
            };
            motionRef.current = mock_motion;
            lastMotionRef.current = mock_motion;
            if not geolocationRef.current {
                geolocationRef.current = {
                    "lat": 37.774900,
                    "lng": -122.419400,
                    "alt": 15.0,
                    "speed": 3.2,
                    "accuracy": 8.0
                };
            }
            emit_data();

            decision = await decide_motion_with_walker(mock_motion, agentConfig, True);
            if decision and decision.priority > 0 {
                await handleAction(decision);
            }
            await evaluate_rules_and_act(mock_motion, "simulate");
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

            # Only attach motion listener if not already attached
            if not motionListenerAttached.current {
                print("Attaching motion listener for first time");
                Motion.addListener(
                    "accel",
                    lambda event: Any -> None {
                        # Check tracking flag - skip processing if not tracking
                        if not isTrackingRef.current {
                            return;
                        }

                        print("Motion event raw", event);
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
                        emit_data();

                        lastMotionRef.current = motionRef.current;

                        # Fall detection - check every motion event
                        detect_fall(ax, ay, az, alpha, beta, gamma);

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
                ).then(
                    lambda handle: Any -> None {
                        accelSubRef.current = handle;
                        motionListenerAttached.current = True;
                        print("Motion listener attached successfully");
                    }
                ).catch(
                    lambda e: Any -> None {
                        print("Motion listener error", e);
                    }
                );
            } else {
                print("Motion listener already attached, reusing existing");
            }

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
                            "lat": pos.coords.latitude,
                            "lng": pos.coords.longitude,
                            "alt": pos.coords.altitude if pos.coords.altitude else 0,
                            "speed": pos.coords.speed if pos.coords.speed else 0,
                            "accuracy": pos.coords.accuracy if pos.coords.accuracy else 0
                        };
                        detect_geofence_exit(geolocationRef.current);
                        emit_data();
                    }
                }
            ).catch(lambda -> None { ; });

            Geolocation.watchPosition(
                {"enableHighAccuracy": True},
                lambda pos: Any -> None {
                    if pos and pos.coords {
                        geolocationRef.current = {
                            "lat": pos.coords.latitude,
                            "lng": pos.coords.longitude,
                            "alt": pos.coords.altitude if pos.coords.altitude else 0,
                            "speed": pos.coords.speed if pos.coords.speed else 0,
                            "accuracy": pos.coords.accuracy if pos.coords.accuracy else 0
                        };
                        detect_geofence_exit(geolocationRef.current);
                        emit_data();
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

        useEffect(
            lambda -> None {
                checkCapabilities();
                return (lambda -> None {
                    stopTracking();
                });
            },
            []
        );

        motionAccelView = None;
        motionGyroView = None;
        if sensorData.motion {
            motionAccelView =
                <div style={{"display": "flex", "gap": "12px"}}>
                    <div style={{"flex": "1"}}>
                        <label style={{"fontSize": "12px", "color": "#888"}}>X</label>
                        <div>{sensorData.motion.acceleration.x.toFixed(2)}</div>
                    </div>
                    <div style={{"flex": "1"}}>
                        <label style={{"fontSize": "12px", "color": "#888"}}>Y</label>
                        <div>{sensorData.motion.acceleration.y.toFixed(2)}</div>
                    </div>
                    <div style={{"flex": "1"}}>
                        <label style={{"fontSize": "12px", "color": "#888"}}>Z</label>
                        <div>{sensorData.motion.acceleration.z.toFixed(2)}</div>
                    </div>
                </div>;

            motionGyroView =
                <div style={{"display": "flex", "gap": "12px", "marginTop": "8px"}}>
                    <div style={{"flex": "1"}}>
                        <label style={{"fontSize": "12px", "color": "#888"}}>Alpha</label>
                        <div>{sensorData.motion.rotationRate.alpha.toFixed(2)}</div>
                    </div>
                    <div style={{"flex": "1"}}>
                        <label style={{"fontSize": "12px", "color": "#888"}}>Beta</label>
                        <div>{sensorData.motion.rotationRate.beta.toFixed(2)}</div>
                    </div>
                    <div style={{"flex": "1"}}>
                        <label style={{"fontSize": "12px", "color": "#888"}}>Gamma</label>
                        <div>{sensorData.motion.rotationRate.gamma.toFixed(2)}</div>
                    </div>
                </div>;
        }

        compassView = None;
        if sensorData.compass {
            compassView =
                <div style={{"fontSize": "12px"}}>
                    Heading: {sensorData.compass.heading.toFixed(1)} deg
                </div>;
        }

        barometerView = None;
        if sensorData.barometer {
            barometerView =
                <div style={{"display": "flex", "gap": "12px", "fontSize": "12px"}}>
                    <div>Pressure: {sensorData.barometer.pressure.toFixed(1)}</div>
                    <div>Alt: {sensorData.barometer.relativeAltitude.toFixed(1)}m</div>
                </div>;
        }

        geoView = None;
        if sensorData.geolocation {
            geoView =
                <div style={{"display": "grid", "gridTemplateColumns": "repeat(2, 1fr)", "gap": "8px", "fontSize": "12px"}}>
                    <div>Lat: {sensorData.geolocation.lat.toFixed(6)}</div>
                    <div>Lng: {sensorData.geolocation.lng.toFixed(6)}</div>
                    <div>Alt: {sensorData.geolocation.alt.toFixed(1)}m</div>
                    <div>Speed: {sensorData.geolocation.speed.toFixed(1)}m/s</div>
                </div>;
        }

        deviceView = None;
        if sensorData.device {
            deviceView =
                <div style={{"fontSize": "12px", "color": "#888"}}>
                    <div>{sensorData.device.model}</div>
                    <div>Android {sensorData.device.androidSDKVersion}</div>
                </div>;
        }

        decisionsView = None;
        if decisions.length == 0 {
            decisionsView =
                <p style={{"fontSize": "12px", "color": "#888"}}>
                    No decisions yet
                </p>;
        } else {
            decisionsView =
                <div style={{"display": "grid", "gap": "8px", "fontSize": "12px"}}>
                    <div style={{"color": "#94a3b8"}}>Total: {decisions.length}</div>
                    <div>
                        Last: {decisions[decisions.length - 1].message}
                    </div>
                </div>;
        }

        # Fall detection countdown overlay
        fallOverlay = None;
        if fallCountdown > 0 {
            fallOverlay =
                <div style={{
                    "position": "fixed",
                    "top": "0",
                    "left": "0",
                    "right": "0",
                    "bottom": "0",
                    "background": "rgba(220, 38, 38, 0.95)",
                    "display": "flex",
                    "flexDirection": "column",
                    "alignItems": "center",
                    "justifyContent": "center",
                    "zIndex": "9999",
                    "color": "#fff",
                    "padding": "24px"
                }}>
                    <div style={{
                        "fontSize": "24px",
                        "fontWeight": "700",
                        "marginBottom": "16px",
                        "textAlign": "center"
                    }}>
                        FALL DETECTED
                    </div>
                    <div style={{
                        "fontSize": "72px",
                        "fontWeight": "800",
                        "marginBottom": "24px"
                    }}>
                        {fallCountdown}
                    </div>
                    <div style={{
                        "fontSize": "16px",
                        "marginBottom": "32px",
                        "textAlign": "center",
                        "maxWidth": "280px"
                    }}>
                        Emergency call will be placed in {fallCountdown} seconds
                    </div>
                    <button
                        onClick={cancel_fall_countdown}
                        style={{
                            "padding": "16px 48px",
                            "fontSize": "18px",
                            "fontWeight": "700",
                            "background": "#fff",
                            "color": "#dc2626",
                            "border": "none",
                            "borderRadius": "12px",
                            "cursor": "pointer"
                        }}
                    >
                        I'M OK - CANCEL
                    </button>
                    <div style={{
                        "marginTop": "24px",
                        "fontSize": "14px",
                        "opacity": "0.8"
                    }}>
                        Calling: {emergency_contact_name()}
                    </div>
                </div>;
        }

        statusClass = "#22c55e" if isTracking else "#888";

        return
            <div style={{
                "maxWidth": "480px",
                "margin": "0 auto",
                "padding": "16px",
                "minHeight": "100vh",
                "background": "#0f0f0f",
                "color": "#e0e0e0",
                "fontFamily": "-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif"
            }}>
                <header style={{
                    "display": "flex",
                    "justifyContent": "space-between",
                    "alignItems": "center",
                    "padding": "16px 0",
                    "borderBottom": "1px solid #333",
                    "marginBottom": "20px"
                }}>
                    <h1 style={{"fontSize": "20px", "margin": "0"}}>Sensor Agent</h1>
                    <span style={{
                        "fontSize": "12px",
                        "padding": "4px 12px",
                        "borderRadius": "20px",
                        "background": "#1a1a1a",
                        "color": statusClass
                    }}>
                        {"Running" if isTracking else "Idle"}
                    </span>
                </header>

                <main style={{"display": "flex", "flexDirection": "column", "gap": "16px"}}>
                    <section style={{"background": "#1a1a1a", "borderRadius": "12px", "padding": "16px"}}>
                        <h2 style={{"fontSize": "14px", "color": "#888", "margin": "0 0 8px 0"}}>
                            Motion Sensors
                        </h2>

                        <div style={{
                            "display": "flex",
                            "gap": "8px",
                            "marginBottom": "12px",
                            "fontSize": "11px",
                            "flexWrap": "wrap"
                        }}>
                            <span style={{"color": "#4ade80"}}>Accel</span>
                            <span style={{"color": "#4ade80"}}>Gyro</span>
                            <span style={{"color": ("#4ade80" if capabilities and capabilities.compass else "#ef4444")}}>
                                Compass
                            </span>
                            <span style={{"color": ("#4ade80" if capabilities and capabilities.barometer else "#ef4444")}}>
                                Baro
                            </span>
                            <span style={{"color": ("#4ade80" if capabilities and capabilities.geolocation else "#ef4444")}}>
                                GPS
                            </span>
                            <span style={{"color": "#4ade80"}}>Prox</span>
                            <span style={{"color": "#4ade80"}}>Mic</span>
                        </div>

                        <label style={{"fontSize": "11px", "color": "#888", "display": "block", "marginBottom": "8px"}}>
                            Accelerometer (m/s2)
                        </label>
                        {motionAccelView}

                        <label style={{"fontSize": "11px", "color": "#888", "display": "block", "margin": "12px 0 8px 0"}}>
                            Gyroscope (deg/s)
                        </label>
                        {motionGyroView}

                        <label style={{"fontSize": "11px", "color": "#888", "display": "block", "margin": "12px 0 8px 0"}}>
                            Compass (degrees)
                        </label>
                        {compassView}

                        <label style={{"fontSize": "11px", "color": "#888", "display": "block", "margin": "12px 0 8px 0"}}>
                            Barometer (hPa)
                        </label>
                        {barometerView}

                        <label style={{"fontSize": "11px", "color": "#888", "display": "block", "margin": "12px 0 8px 0"}}>
                            Geolocation
                        </label>
                        {geoView}

                        <label style={{"fontSize": "11px", "color": "#888", "display": "block", "margin": "12px 0 8px 0"}}>
                            Microphone
                        </label>
                        <button
                            onClick={handleMicToggle}
                            style={{
                                "width": "100%",
                                "padding": "10px",
                                "border": "none",
                                "borderRadius": "8px",
                                "fontSize": "14px",
                                "fontWeight": "500",
                                "background": "#8b5cf6",
                                "color": "#fff",
                                "cursor": "pointer"
                            }}
                        >
                            {("Stop Recording" if isRecording else "Start Recording")}
                        </button>

                        <label style={{"fontSize": "11px", "color": "#888", "display": "block", "margin": "12px 0 8px 0"}}>
                            Device
                        </label>
                        {deviceView}

                        <button
                            onClick={handleTakePhoto}
                            style={{
                                "width": "100%",
                                "padding": "12px",
                                "marginTop": "12px",
                                "border": "none",
                                "borderRadius": "8px",
                                "fontSize": "14px",
                                "fontWeight": "600",
                                "background": "#3b82f6",
                                "color": "#fff",
                                "cursor": "pointer"
                            }}
                        >
                            {("Photo Taken!" if lastPhoto else "Take Photo")}
                        </button>
                        {( 
                            <p style={{"fontSize": "11px", "color": "#4ade80", "textAlign": "center", "marginTop": "8px"}}>
                                Photo saved
                            </p>
                        ) if lastPhoto else None}
                    </section>

                    <section style={{"background": "#1a1a1a", "borderRadius": "12px", "padding": "16px"}}>
                        <h2 style={{"fontSize": "14px", "color": "#888", "margin": "0 0 8px 0"}}>
                            AI Agent
                        </h2>
                        <div style={{"display": "flex", "gap": "16px", "fontSize": "12px", "color": "#888", "marginBottom": "12px"}}>
                            <span>Decisions: {decisions.length}</span>
                            <span>Running: {("Yes" if agentRunning else "No")}</span>
                        </div>

                        {(
                            <button
                                onClick={startTracking}
                                style={{
                                    "width": "100%",
                                    "padding": "12px",
                                    "border": "none",
                                    "borderRadius": "8px",
                                    "fontSize": "14px",
                                    "fontWeight": "600",
                                    "cursor": "pointer",
                                    "background": "#4ade80",
                                    "color": "#000"
                                }}
                            >
                                Start Agent
                            </button>
                        ) if not isTracking else (
                            <button
                                onClick={stopTracking}
                                style={{
                                    "width": "100%",
                                    "padding": "12px",
                                    "border": "none",
                                    "borderRadius": "8px",
                                    "fontSize": "14px",
                                    "fontWeight": "600",
                                    "cursor": "pointer",
                                    "background": "#ef4444",
                                    "color": "#fff"
                                }}
                            >
                                Stop Agent
                            </button>
                        )}

                        <button
                            onClick={simulate_sensor_event}
                            style={{
                                "width": "100%",
                                "padding": "10px",
                                "marginTop": "10px",
                                "border": "none",
                                "borderRadius": "8px",
                                "fontSize": "13px",
                                "fontWeight": "600",
                                "cursor": "pointer",
                                "background": "#f59e0b",
                                "color": "#111"
                            }}
                        >
                            Simulate Sensor Event
                        </button>
                    </section>

                    <section style={{"background": "#1a1a1a", "borderRadius": "12px", "padding": "16px"}}>
                        <h2 style={{"fontSize": "14px", "color": "#888", "margin": "0 0 12px 0"}}>
                            Rules Manager (IF/THEN)
                        </h2>

                        <input
                            placeholder="Rule name"
                            value={ruleDraft.name}
                            onChange={lambda e: Any -> None {
                                setRuleDraft(lambda prev: Any -> Any {
                                    next_draft = Object.assign({}, prev);
                                    next_draft.name = e.target.value;
                                    return next_draft;
                                });
                            }}
                            style={{
                                "width": "100%",
                                "padding": "8px",
                                "borderRadius": "8px",
                                "border": "1px solid #333",
                                "background": "#111",
                                "color": "#e0e0e0",
                                "marginBottom": "8px"
                            }}
                        />

                        <div style={{"display": "grid", "gridTemplateColumns": "1fr 90px", "gap": "8px", "marginBottom": "8px"}}>
                            <select
                                value={ruleDraft.conditionType}
                                onChange={lambda e: Any -> None {
                                    setRuleDraft(lambda prev: Any -> Any {
                                        next_draft = Object.assign({}, prev);
                                        next_draft.conditionType = e.target.value;
                                        return next_draft;
                                    });
                                }}
                                style={{
                                    "padding": "8px",
                                    "borderRadius": "8px",
                                    "border": "1px solid #333",
                                    "background": "#111",
                                    "color": "#e0e0e0"
                                }}
                            >
                                <option value="motion_intensity_gt">IF motion &gt;</option>
                                <option value="speed_gt">IF speed &gt;</option>
                            </select>
                            <input
                                value={ruleDraft.conditionValue}
                                onChange={lambda e: Any -> None {
                                    setRuleDraft(lambda prev: Any -> Any {
                                        next_draft = Object.assign({}, prev);
                                        next_draft.conditionValue = e.target.value;
                                        return next_draft;
                                    });
                                }}
                                style={{
                                    "padding": "8px",
                                    "borderRadius": "8px",
                                    "border": "1px solid #333",
                                    "background": "#111",
                                    "color": "#e0e0e0"
                                }}
                            />
                        </div>

                        <div style={{"display": "grid", "gridTemplateColumns": "1fr", "gap": "8px", "marginBottom": "8px"}}>
                            <select
                                value={ruleDraft.actionType}
                                onChange={lambda e: Any -> None {
                                    setRuleDraft(lambda prev: Any -> Any {
                                        next_draft = Object.assign({}, prev);
                                        next_draft.actionType = e.target.value;
                                        return next_draft;
                                    });
                                }}
                                style={{
                                    "padding": "8px",
                                    "borderRadius": "8px",
                                    "border": "1px solid #333",
                                    "background": "#111",
                                    "color": "#e0e0e0"
                                }}
                            >
                                <option value="notify">THEN notify</option>
                                <option value="maps_home">THEN open maps</option>
                                <option value="webhook">THEN send webhook</option>
                            </select>
                            <input
                                placeholder="Action value (message, destination, or webhook URL)"
                                value={ruleDraft.actionValue}
                                onChange={lambda e: Any -> None {
                                    setRuleDraft(lambda prev: Any -> Any {
                                        next_draft = Object.assign({}, prev);
                                        next_draft.actionValue = e.target.value;
                                        return next_draft;
                                    });
                                }}
                                style={{
                                    "padding": "8px",
                                    "borderRadius": "8px",
                                    "border": "1px solid #333",
                                    "background": "#111",
                                    "color": "#e0e0e0"
                                }}
                            />
                        </div>

                        <button
                            onClick={add_rule}
                            style={{
                                "width": "100%",
                                "padding": "10px",
                                "border": "none",
                                "borderRadius": "8px",
                                "fontWeight": "600",
                                "background": "#22c55e",
                                "color": "#111",
                                "marginBottom": "12px"
                            }}
                        >
                            Add Rule
                        </button>

                        <div style={{"display": "grid", "gap": "8px"}}>
                            {rules.map(lambda rule: Any -> JsxElement {
                                return <div
                                    key={rule.id}
                                    style={{
                                        "border": "1px solid #2a2a2a",
                                        "borderRadius": "8px",
                                        "padding": "10px",
                                        "fontSize": "12px"
                                    }}
                                >
                                    <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "gap": "8px"}}>
                                        <strong style={{"color": "#e2e8f0"}}>{rule.name}</strong>
                                        <span style={{"color": ("#4ade80" if rule.enabled else "#ef4444")}}>
                                            {("Enabled" if rule.enabled else "Disabled")}
                                        </span>
                                    </div>
                                    <div style={{"marginTop": "4px", "color": "#94a3b8"}}>
                                        IF {rule.condition.type} {String(rule.condition.value)} THEN {rule.action.type}
                                    </div>
                                    <div style={{"marginTop": "4px", "color": "#cbd5e1"}}>{rule.action.value}</div>
                                    <div style={{"display": "flex", "gap": "8px", "marginTop": "8px"}}>
                                        <button
                                            onClick={lambda -> None { toggle_rule(rule.id); }}
                                            style={{
                                                "flex": "1",
                                                "padding": "8px",
                                                "border": "none",
                                                "borderRadius": "6px",
                                                "background": ("#f59e0b" if rule.enabled else "#22c55e"),
                                                "color": "#111"
                                            }}
                                        >
                                            {("Disable" if rule.enabled else "Enable")}
                                        </button>
                                        <button
                                            onClick={lambda -> None { remove_rule(rule.id); }}
                                            style={{
                                                "flex": "1",
                                                "padding": "8px",
                                                "border": "none",
                                                "borderRadius": "6px",
                                                "background": "#ef4444",
                                                "color": "#fff"
                                            }}
                                        >
                                            Delete
                                        </button>
                                    </div>
                                </div>;
                            })}
                        </div>
                    </section>

                    <section style={{"background": "#1a1a1a", "borderRadius": "12px", "padding": "16px"}}>
                        <h2 style={{"fontSize": "14px", "color": "#888", "margin": "0 0 12px 0"}}>
                            Recent Decisions
                        </h2>
                        {decisionsView}
                    </section>
                </main>
                {fallOverlay}
            </div>;
    }
}
