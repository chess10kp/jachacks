"""Hijac Sensor Agent - Sample PWA with Capacitor sensors."""

cl import from react { useState, useEffect, useRef }
cl import from "@capacitor/motion" { Motion }
cl import from "@capacitor/haptics" { Haptics, ImpactStyle }
cl import from "@capacitor/device" { Device }

cl {
    def calculate_motion_intensity(data: Any) -> float {
        accel = data.acceleration;
        x = accel.x;
        y = accel.y;
        z = accel.z;
        return (x * x + y * y + z * z) ** 0.5;
    }

    def generate_decision(motion_data: Any, config: dict) -> dict {
        intensity = calculate_motion_intensity(motion_data);
        is_high_motion = intensity > config.motionThreshold;

        if is_high_motion {
            return {
                "type": "trigger" if config.autoAct else "notify",
                "message": "High motion detected: intensity "
                    + intensity.toFixed(2),
                "priority": 2 if intensity > 10 else 1
            };
        }

        return {
            "type": "log",
            "message": "Normal motion: intensity " + intensity.toFixed(2),
            "priority": 0
        };
    }

    async def query_ai(motion_data: Any, config: dict) -> dict {
        intensity = calculate_motion_intensity(motion_data);
        state = "active" if intensity > config.motionThreshold else "idle";

        return {
            "type": "trigger" if config.autoAct else "notify",
            "message": "Motion state: " + state + ", intensity "
                + intensity.toFixed(1),
            "priority": Math.floor(intensity / 5)
        };
    }

    def:pub app -> JsxElement {
        [isTracking, setIsTracking] = useState(false);
        [motionData, setMotionData] = useState(None);
        [decisions, setDecisions] = useState([]);
        [capabilities, setCapabilities] = useState(
            {"accelerometer": True, "gyroscope": False}
        );
        [deviceInfo, setDeviceInfo] = useState(None);

        accelSubRef = useRef(None);
        decisionLoopRef = useRef(None);
        lastMotionRef = useRef(None);

        agentConfig = {
            "apiEndpoint": "",
            "motionThreshold": 2.5,
            "decisionInterval": 3000,
            "autoAct": True
        };

        async def handleAction(action: dict) -> None {
            setDecisions(
                lambda prev: list -> list {
                    return prev.slice(-9).concat([action]);
                }
            );
            if action.type == "trigger" {
                try {
                    await Haptics.impact({"style": ImpactStyle.Heavy});
                } except Exception as e {
                    print("Haptics not available");
                }
            }
        }

        def stopTracking -> None {
            if accelSubRef.current {
                accelSubRef.current.remove();
                accelSubRef.current = None;
            }
            try {
                Motion.removeAllListeners();
            } except Exception as e {
                ;
            }
            if decisionLoopRef.current {
                clearInterval(decisionLoopRef.current);
                decisionLoopRef.current = None;
            }
            setIsTracking(false);
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
                        decision = await query_ai(
                            lastMotionRef.current, agentConfig
                        );
                        if decision.priority > 0 {
                            await handleAction(decision);
                        }
                    }
                    runDecision();
                },
                agentConfig.decisionInterval
            );
        }

        def startTracking -> None {
            if isTracking {
                return;
            }
            startDecisionLoop();
            Motion.addListener(
                "accel",
                lambda event: Any -> None {
                    data = {
                        "acceleration": {
                            "x": event.acceleration.x,
                            "y": event.acceleration.y,
                            "z": event.acceleration.z
                        },
                        "rotationRate": {
                            "alpha": event.rotationRate.alpha,
                            "beta": event.rotationRate.beta,
                            "gamma": event.rotationRate.gamma
                        },
                        "timestamp": Date.now()
                    };
                    setMotionData(data);
                    lastMotionRef.current = data;
                    localDecision = generate_decision(data, agentConfig);
                    if localDecision.priority > 0 {
                        handleAction(localDecision);
                    }
                }
            ).then(lambda handle: Any -> None { accelSubRef.current = handle; });

            setIsTracking(true);
        }

        async def loadDeviceInfo -> None {
            try {
                info = await Device.getInfo();
                setDeviceInfo(info);
            } except Exception as e {
                ;
            }
        }

        useEffect(
            lambda -> None {
                loadDeviceInfo();
                return (lambda -> None { stopTracking(); });
            },
            []
        );

        motionAccelView = None;
        motionGyroView = None;
        if motionData {
            motionAccelView =
                <div style={{
                    "display": "grid",
                    "gridTemplateColumns": "repeat(3, 1fr)",
                    "gap": "8px",
                    "fontSize": "12px"
                }}>
                    <div>
                        <div style={{"color": "#94a3b8"}}>X</div>
                        <div>{motionData.acceleration.x.toFixed(2)}</div>
                    </div>
                    <div>
                        <div style={{"color": "#94a3b8"}}>Y</div>
                        <div>{motionData.acceleration.y.toFixed(2)}</div>
                    </div>
                    <div>
                        <div style={{"color": "#94a3b8"}}>Z</div>
                        <div>{motionData.acceleration.z.toFixed(2)}</div>
                    </div>
                </div>;

            motionGyroView =
                <div style={{
                    "display": "grid",
                    "gridTemplateColumns": "repeat(3, 1fr)",
                    "gap": "8px",
                    "fontSize": "12px",
                    "marginTop": "8px"
                }}>
                    <div>
                        <div style={{"color": "#94a3b8"}}>Alpha</div>
                        <div>{motionData.rotationRate.alpha.toFixed(2)}</div>
                    </div>
                    <div>
                        <div style={{"color": "#94a3b8"}}>Beta</div>
                        <div>{motionData.rotationRate.beta.toFixed(2)}</div>
                    </div>
                    <div>
                        <div style={{"color": "#94a3b8"}}>Gamma</div>
                        <div>{motionData.rotationRate.gamma.toFixed(2)}</div>
                    </div>
                </div>;
        }

        decisionsView = None;
        if decisions.length == 0 {
            decisionsView =
                <p style={{
                    "fontSize": "12px",
                    "color": "#94a3b8"
                }}>
                    No decisions yet
                </p>;
        } else {
            decisionsView =
                <ul style={{
                    "listStyle": "none",
                    "padding": "0",
                    "margin": "0",
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": "8px",
                    "fontSize": "12px"
                }}>
                    [
                        <li
                            key={d.message}
                            style={{
                                "display": "flex",
                                "gap": "8px",
                                "padding": "8px",
                                "borderRadius": "8px",
                                "backgroundColor": "#111827",
                                "border": "1px solid #1f2937"
                            }}
                        >
                            <span style={{
                                "minWidth": "56px",
                                "color": "#38bdf8",
                                "textTransform": "uppercase"
                            }}>
                                {d.type}
                            </span>
                            <span style={{"color": "#e5e7eb"}}>
                                {d.message}
                            </span>
                        </li>
                        for d in decisions
                    ]
                </ul>;
        }

        deviceView = None;
        if deviceInfo {
            deviceView =
                <div style={{
                    "backgroundColor": "#0f172a",
                    "borderRadius": "12px",
                    "padding": "16px",
                    "marginBottom": "16px",
                    "border": "1px solid #1e293b"
                }}>
                    <h2 style={{"fontSize": "16px", "margin": "0 0 12px 0"}}>
                        Device
                    </h2>
                    <div style={{"fontSize": "12px", "color": "#94a3b8"}}>
                        <div>Model: {deviceInfo.model}</div>
                        <div>Platform: {deviceInfo.platform}</div>
                        <div>OS: {deviceInfo.operatingSystem}</div>
                    </div>
                </div>;
        }

        return
            <div style={{
                "fontFamily": "system-ui, sans-serif",
                "maxWidth": "520px",
                "margin": "0 auto",
                "padding": "20px",
                "backgroundColor": "#0b1220",
                "color": "#e5e7eb",
                "minHeight": "100vh"
            }}>
                <header style={{
                    "display": "flex",
                    "justifyContent": "space-between",
                    "alignItems": "center",
                    "marginBottom": "16px"
                }}>
                    <h1 style={{
                        "fontSize": "24px",
                        "margin": "0",
                        "color": "#38bdf8"
                    }}>
                        Sensor Agent
                    </h1>
                    <span style={{
                        "padding": "4px 10px",
                        "borderRadius": "12px",
                        "fontSize": "12px",
                        "fontWeight": "600",
                        "backgroundColor": "#1f2937",
                        "color": "#94a3b8"
                    }}>
                        {"Running" if isTracking else "Idle"}
                    </span>
                </header>

                <div style={{
                    "backgroundColor": "#0f172a",
                    "borderRadius": "12px",
                    "padding": "16px",
                    "marginBottom": "16px",
                    "border": "1px solid #1e293b"
                }}>
                    <h2 style={{"fontSize": "16px", "margin": "0 0 12px 0"}}>
                        Motion Sensors
                    </h2>
                    <label style={{"fontSize": "12px", "color": "#94a3b8"}}>
                        Accelerometer
                    </label>
                    <div style={{
                        "display": "flex",
                        "gap": "12px",
                        "margin": "8px 0 12px 0",
                        "fontSize": "12px"
                    }}>
                        <span style={{
                            "color": "#22c55e" if capabilities.accelerometer
                                else "#ef4444"
                        }}>
                            {"Available" if capabilities.accelerometer else "Unavailable"}
                        </span>
                        <span style={{
                            "color": "#22c55e" if capabilities.gyroscope
                                else "#ef4444"
                        }}>
                            {"Gyroscope Available" if capabilities.gyroscope
                                else "Gyroscope Unavailable"}
                        </span>
                    </div>
                    {motionAccelView}

                    <label style={{
                        "display": "block",
                        "fontSize": "12px",
                        "color": "#94a3b8",
                        "marginTop": "12px"
                    }}>
                        Gyroscope (deg/s)
                    </label>
                    {motionGyroView}
                </div>

                <div style={{
                    "backgroundColor": "#0f172a",
                    "borderRadius": "12px",
                    "padding": "16px",
                    "marginBottom": "16px",
                    "border": "1px solid #1e293b"
                }}>
                    <h2 style={{"fontSize": "16px", "margin": "0 0 12px 0"}}>
                        AI Agent
                    </h2>
                    <div style={{
                        "display": "flex",
                        "justifyContent": "space-between",
                        "fontSize": "12px",
                        "color": "#94a3b8",
                        "marginBottom": "12px"
                    }}>
                        <span>Decisions: {decisions.length}</span>
                        <span>Running: {"Yes" if isTracking else "No"}</span>
                    </div>
                    if not isTracking {
                        <button
                            onClick={startTracking}
                            style={{
                                "width": "100%",
                                "padding": "10px",
                                "borderRadius": "8px",
                                "border": "none",
                                "backgroundColor": "#38bdf8",
                                "color": "#0b1220",
                                "fontWeight": "600",
                                "cursor": "pointer"
                            }}
                        >
                            Start Agent
                        </button>;
                    } else {
                        <button
                            onClick={stopTracking}
                            style={{
                                "width": "100%",
                                "padding": "10px",
                                "borderRadius": "8px",
                                "border": "1px solid #1e293b",
                                "backgroundColor": "#111827",
                                "color": "#e5e7eb",
                                "fontWeight": "600",
                                "cursor": "pointer"
                            }}
                        >
                            Stop Agent
                        </button>;
                    }
                </div>

                {deviceView}

                <div style={{
                    "backgroundColor": "#0f172a",
                    "borderRadius": "12px",
                    "padding": "16px",
                    "border": "1px solid #1e293b"
                }}>
                    <h2 style={{"fontSize": "16px", "margin": "0 0 12px 0"}}>
                        Recent Decisions
                    </h2>
                    {decisionsView}
                </div>
            </div>;
    }
}
