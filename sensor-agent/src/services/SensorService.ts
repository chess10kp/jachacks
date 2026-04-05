import { Motion, type AccelListenerEvent } from '@capacitor/motion';

export interface MotionData {
  acceleration: { x: number; y: number; z: number };
  rotationRate: { alpha: number; beta: number; gamma: number };
  timestamp: number;
}

export interface SensorConfig {
  accelerometerInterval: number;
  gyroscopeInterval: number;
}

type MotionListener = (data: MotionData) => void;

let motionListener: MotionListener | null = null;
let accelSubscription: { remove: () => void } | null = null;

export const SensorService = {
  startMotionTracking(_config: SensorConfig, listener: MotionListener) {
    motionListener = listener;
    
    Motion.addListener('accel', (event: AccelListenerEvent) => {
      if (motionListener) {
        motionListener({
          acceleration: { x: event.acceleration.x, y: event.acceleration.y, z: event.acceleration.z },
          rotationRate: { alpha: event.rotationRate.alpha, beta: event.rotationRate.beta, gamma: event.rotationRate.gamma },
          timestamp: Date.now()
        });
      }
    }).then(handle => {
      accelSubscription = handle;
    });
  },

  stopMotionTracking() {
    if (accelSubscription) {
      accelSubscription.remove();
      accelSubscription = null;
    }
    motionListener = null;
    Motion.removeAllListeners();
  },

  getMotionCapabilities() {
    return Promise.resolve({ accelerometer: true, gyroscope: false });
  }
};