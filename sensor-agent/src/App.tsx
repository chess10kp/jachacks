import { useState, useEffect } from 'react';
import { Haptics, ImpactStyle } from '@capacitor/haptics';
import { SensorService, type MotionData, type SensorConfig } from './services/SensorService';
import { AIAgent, type AgentAction, type AgentConfig } from './services/AIAgent';
import './App.css';

function App() {
  const [isTracking, setIsTracking] = useState(false);
  const [motionData, setMotionData] = useState<MotionData | null>(null);
  const [decisions, setDecisions] = useState<AgentAction[]>([]);
  const [capabilities, setCapabilities] = useState<{ accelerometer: boolean; gyroscope: boolean } | null>(null);
  const [agentState, setAgentState] = useState(AIAgent.getState());

  useEffect(() => {
    checkCapabilities();
    return () => {
      SensorService.stopMotionTracking();
      AIAgent.stop();
    };
  }, []);

  const checkCapabilities = async () => {
    const caps = await SensorService.getMotionCapabilities();
    setCapabilities(caps);
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

  const startTracking = () => {
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

    SensorService.startMotionTracking(sensorConfig, (data) => {
      setMotionData(data);
      AIAgent.processSensorData(data);
      setAgentState(AIAgent.getState());
    });

    setIsTracking(true);
  };

  const stopTracking = () => {
    SensorService.stopMotionTracking();
    AIAgent.stop();
    setIsTracking(false);
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
          <label className="section-label">Accelerometer</label>
          {capabilities && (
            <div className="sensor-status">
              <span className={capabilities.accelerometer ? 'available' : 'unavailable'}>
                Accelerometer {capabilities.accelerometer ? '✓' : '✗'}
              </span>
              <span className={capabilities.gyroscope ? 'available' : 'unavailable'}>
                Gyroscope {capabilities.gyroscope ? '✓' : '✗'}
              </span>
            </div>
          )}
          
          {motionData && (
            <div className="sensor-data">
              <div className="data-row">
                <label>X</label>
                <span>{motionData.acceleration.x.toFixed(2)}</span>
              </div>
              <div className="data-row">
                <label>Y</label>
                <span>{motionData.acceleration.y.toFixed(2)}</span>
              </div>
              <div className="data-row">
                <label>Z</label>
                <span>{motionData.acceleration.z.toFixed(2)}</span>
              </div>
            </div>
          )}
          
          <label className="section-label">Gyroscope (deg/s)</label>
          {motionData && (
            <div className="sensor-data gyro">
              <div className="data-row">
                <label>α</label>
                <span>{motionData.rotationRate.alpha.toFixed(2)}</span>
              </div>
              <div className="data-row">
                <label>β</label>
                <span>{motionData.rotationRate.beta.toFixed(2)}</span>
              </div>
              <div className="data-row">
                <label>γ</label>
                <span>{motionData.rotationRate.gamma.toFixed(2)}</span>
              </div>
            </div>
          )}
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