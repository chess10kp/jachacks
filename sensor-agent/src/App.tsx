import { useState, useEffect, useRef } from 'react';
import { Haptics, ImpactStyle } from '@capacitor/haptics';
import { SensorService, type SensorData, type SensorConfig } from './services/SensorService';
import { AIAgent, type AgentAction, type AgentConfig } from './services/AIAgent';
import './App.css';

function App() {
  const [isTracking, setIsTracking] = useState(false);
  const [sensorData, setSensorData] = useState<SensorData>({ motion: null, barometer: null, compass: null, geolocation: null, pedometer: null, proximity: null, device: null, camera: null });
  const motionRef = useRef(sensorData.motion);
  const barometerRef = useRef(sensorData.barometer);
  const compassRef = useRef(sensorData.compass);
  const geolocationRef = useRef(sensorData.geolocation);
  const proximityRef = useRef(sensorData.proximity);
  proximityRef.current = sensorData.proximity;
  const [lastPhoto, setLastPhoto] = useState<string | null>(null);
  const [isRecording, setIsRecording] = useState(false);
  const [decisions, setDecisions] = useState<AgentAction[]>([]);
  const [capabilities, setCapabilities] = useState<{ accelerometer: boolean; gyroscope: boolean; barometer: boolean; compass: boolean; geolocation: boolean; proximity: boolean } | null>(null);
  const [agentState, setAgentState] = useState(AIAgent.getState());

  useEffect(() => {
    checkCapabilities();
    return () => {
      SensorService.stopAllSensors();
      AIAgent.stop();
    };
  }, []);

  const checkCapabilities = async () => {
    const caps = await SensorService.getCapabilities();
    const baro = await SensorService.checkBarometer();
    const comp = await SensorService.checkCompass();
    const geo = await SensorService.checkGeolocation();
    await SensorService.checkPedometer();
    setCapabilities({ ...caps, barometer: baro, compass: comp, geolocation: geo, proximity: true });
  };

  const handleAction = async (action: AgentAction) => {
    setDecisions(prev => [...prev.slice(-9), action]);
    
    if (action.type === 'trigger') {
      try {
        await Haptics.impact({ style: ImpactStyle.Heavy });
      } catch (e) {
        console.log('Haptics not available');
      }
    }
  };

  const handleTakePhoto = async () => {
    const photo = await SensorService.takePhoto();
    if (photo) {
      setLastPhoto(photo);
    }
  };

  const startTracking = async () => {
    await SensorService.requestPermissions();
    
    const sensorConfig: SensorConfig = {
      accelerometerInterval: 100,
      gyroscopeInterval: 100
    };

    const agentConfig: AgentConfig = {
      apiEndpoint: '',
      motionThreshold: 2.5,
      decisionInterval: 3000,
      autoAct: true
    };

    AIAgent.configure(agentConfig);
    AIAgent.start(handleAction);

    SensorService.startAllSensors(sensorConfig, (data) => {
      console.log('Sensor data received:', data);
      if (data.motion) motionRef.current = data.motion;
      if (data.barometer) barometerRef.current = data.barometer;
      if (data.compass) compassRef.current = data.compass;
      if (data.geolocation) geolocationRef.current = data.geolocation;
      if (data.proximity) proximityRef.current = data.proximity;
      
      setSensorData({
        motion: motionRef.current,
        barometer: barometerRef.current,
        compass: compassRef.current,
        geolocation: data.geolocation || sensorData.geolocation,
        pedometer: data.pedometer || sensorData.pedometer,
        proximity: data.proximity || sensorData.proximity,
        device: data.device || sensorData.device
      });

      if (data.motion) {
        AIAgent.processSensorData({
          acceleration: data.motion.acceleration,
          rotationRate: data.motion.rotationRate,
          timestamp: data.motion.timestamp
        });
        setAgentState(AIAgent.getState());
      }
    });

    setIsTracking(true);
  };

  const stopTracking = () => {
    SensorService.stopAllSensors();
    AIAgent.stop();
    setIsTracking(false);
    motionRef.current = null;
    barometerRef.current = null;
    compassRef.current = null;
    geolocationRef.current = null;
  };

  return (
    <div className="app-container">
      <header>
        <h1>Sensor Agent</h1>
        <span className={`status ${isTracking ? 'active' : ''}`}>
          {isTracking ? 'Running' : 'Idle'}
        </span>
      </header>

      <main>
        <section className="card">
          <h2>Motion Sensors</h2>
          {capabilities && (
            <div className="sensor-status">
              <span className={capabilities.accelerometer ? 'available' : 'unavailable'}>Accel</span>
              <span className={capabilities.gyroscope ? 'available' : 'unavailable'}>Gyro</span>
              <span className={capabilities.compass ? 'available' : 'unavailable'}>Compass</span>
              <span className={capabilities.barometer ? 'available' : 'unavailable'}>Baro</span>
              <span className={capabilities.geolocation ? 'available' : 'unavailable'}>GPS</span>
              <span className={capabilities.proximity ? 'available' : 'unavailable'}>Prox</span>
              <span className="available">Mic</span>
            </div>
          )}
           
          <label className="section-label">Accelerometer (m/s²)</label>
          {sensorData.motion && (
            <div className="sensor-data">
              <div className="data-row">
                <label>X</label>
                <span>{sensorData.motion.acceleration.x.toFixed(2)}</span>
              </div>
              <div className="data-row">
                <label>Y</label>
                <span>{sensorData.motion.acceleration.y.toFixed(2)}</span>
              </div>
              <div className="data-row">
                <label>Z</label>
                <span>{sensorData.motion.acceleration.z.toFixed(2)}</span>
              </div>
            </div>
          )}
          
          <label className="section-label">Gyroscope (deg/s)</label>
          {sensorData.motion && (
            <div className="sensor-data gyro">
              <div className="data-row">
                <label>α</label>
                <span>{sensorData.motion.rotationRate.alpha.toFixed(2)}</span>
              </div>
              <div className="data-row">
                <label>β</label>
                <span>{sensorData.motion.rotationRate.beta.toFixed(2)}</span>
              </div>
              <div className="data-row">
                <label>γ</label>
                <span>{sensorData.motion.rotationRate.gamma.toFixed(2)}</span>
              </div>
            </div>
          )}

          <label className="section-label">Compass (degrees)</label>
          {sensorData.compass && (
            <div className="sensor-data">
              <div className="data-row">
                <label>Heading</label>
                <span>{sensorData.compass.heading.toFixed(1)}°</span>
              </div>
            </div>
          )}

          <label className="section-label">Barometer (hPa)</label>
          {sensorData.barometer && (
            <div className="sensor-data">
              <div className="data-row">
                <label>Pressure</label>
                <span>{sensorData.barometer.pressure.toFixed(1)}</span>
              </div>
              <div className="data-row">
                <label>Alt</label>
                <span>{sensorData.barometer.relativeAltitude.toFixed(1)}m</span>
              </div>
            </div>
          )}

          <label className="section-label">Geolocation</label>
          {sensorData.geolocation && (
            <div className="sensor-data">
              <div className="data-row">
                <label>Lat</label>
                <span>{sensorData.geolocation.lat.toFixed(6)}</span>
              </div>
              <div className="data-row">
                <label>Lng</label>
                <span>{sensorData.geolocation.lng.toFixed(6)}</span>
              </div>
              <div className="data-row">
                <label>Alt</label>
                <span>{sensorData.geolocation.alt.toFixed(1)}m</span>
              </div>
              <div className="data-row">
                <label>Speed</label>
                <span>{sensorData.geolocation.speed.toFixed(1)}m/s</span>
              </div>
            </div>
          )}

          <label className="section-label">Microphone</label>
          {sensorData.motion && (
            <button className="mic-btn" onClick={async () => {
              if (isRecording) {
                const file = await SensorService.stopRecording();
                setIsRecording(false);
                if (file) {
                  const secs = Math.round(file.duration / 1000);
                  alert(`Saved!\nDuration: ${secs}s\nPath: ${file.path || 'in memory'}`);
                } else {
                  alert('Recording failed');
                }
              } else {
                const ok = await SensorService.startRecording();
                setIsRecording(ok);
                if (!ok) alert('Permission denied');
              }
            }}>
              {isRecording ? 'Stop Recording' : 'Start Recording'}
            </button>
          )}

          <label className="section-label">Device</label>
          {sensorData.device && (
            <div className="sensor-data device-info">
              <div className="data-row full">
                <span>{sensorData.device.model}</span>
                <span>Android {sensorData.device.androidSDKVersion}</span>
              </div>
            </div>
          )}

          <button className="camera-btn" onClick={handleTakePhoto}>
            {lastPhoto ? 'Photo Taken!' : 'Take Photo'}
          </button>
          {lastPhoto && <p className="photo-taken">Photo saved</p>}
        </section>

        <section className="card">
          <h2>AI Agent</h2>
          <div className="agent-state">
            <span>Decisions: {decisions.length}</span>
            <span>Running: {agentState.isRunning ? 'Yes' : 'No'}</span>
          </div>
          
          {!isTracking ? (
            <button className="start-btn" onClick={startTracking}>
              Start Agent
            </button>
          ) : (
            <button className="stop-btn" onClick={stopTracking}>
              Stop Agent
            </button>
          )}
        </section>

        <section className="card decisions">
          <h2>Recent Decisions</h2>
          {decisions.length === 0 ? (
            <p className="empty">No decisions yet</p>
          ) : (
            <ul>
              {decisions.map((d, i) => (
                <li key={i} className={`priority-${d.priority}`}>
                  <span className="type">{d.type}</span>
                  <span className="message">{d.message}</span>
                </li>
              ))}
            </ul>
          )}
        </section>
      </main>
    </div>
  );
}

export default App;