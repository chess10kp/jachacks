import { Motion, type AccelListenerEvent } from '@capacitor/motion';
import { CapacitorBarometer, type Measurement } from '@capgo/capacitor-barometer';
import { CapgoCompass, type HeadingChangeEvent } from '@capgo/capacitor-compass';
import { Device, type DeviceInfo } from '@capacitor/device';
import { Geolocation, type Position } from '@capacitor/geolocation';
// import { CapacitorPedometer } from '@capgo/capacitor-pedometer';
import { Camera, CameraResultType } from '@capacitor/camera';
import { Microphone } from '@mozartec/capacitor-microphone';

export interface MotionData {
  acceleration: { x: number; y: number; z: number };
  rotationRate: { alpha: number; beta: number; gamma: number };
  timestamp: number;
}

export interface SensorData {
  motion: MotionData | null;
  barometer: { pressure: number; relativeAltitude: number } | null;
  compass: { heading: number } | null;
  geolocation: { lat: number; lng: number; alt: number; speed: number; accuracy: number } | null;
  pedometer: { steps: number; distance: number } | null;
  proximity: { enabled: boolean } | null;
  device: DeviceInfo | null;
  camera?: string | null;
}

export interface SensorConfig {
  accelerometerInterval: number;
  gyroscopeInterval: number;
}

type SensorListener = (data: SensorData) => void;

let sensorListener: SensorListener | null = null;
let accelSubscription: { remove: () => void } | null = null;
let barometerSubscription: { remove: () => void } | null = null;
let compassSubscription: { remove: () => Promise<void> } | null = null;
let geoWatchId: string | null = null;
let cachedMotion: MotionData | null = null;
let cachedBarometer: { pressure: number; relativeAltitude: number } | null = null;
let cachedCompass: { heading: number } | null = null;
let cachedGeolocation: { lat: number; lng: number; alt: number; speed: number; accuracy: number } | null = null;
let cachedPedometer: { steps: number; distance: number } | null = null;
let cachedDevice: DeviceInfo | null = null;

function emit(data: Partial<SensorData> = {}) {
  if (sensorListener) {
    const newData: SensorData = {
      motion: cachedMotion,
      barometer: cachedBarometer,
      compass: cachedCompass,
      geolocation: cachedGeolocation,
      pedometer: cachedPedometer,
      proximity: { enabled: true },
      device: cachedDevice,
      camera: null,
      ...data
    };
    sensorListener(newData);
  }
}

function emitMotion(event: AccelListenerEvent) {
  cachedMotion = {
    acceleration: { x: event.acceleration.x, y: event.acceleration.y, z: event.acceleration.z },
    rotationRate: { alpha: event.rotationRate.alpha, beta: event.rotationRate.beta, gamma: event.rotationRate.gamma },
    timestamp: Date.now()
  };
  emit({});
}

function emitBarometer(event: Measurement) {
  cachedBarometer = { pressure: event.pressure, relativeAltitude: event.relativeAltitude };
  emit({});
}

function emitCompass(event: HeadingChangeEvent) {
  cachedCompass = { heading: event.value };
  emit({});
}

function emitGeolocation(pos: Position | null) {
  if (pos && pos.coords) {
    cachedGeolocation = {
      lat: pos.coords.latitude,
      lng: pos.coords.longitude,
      alt: pos.coords.altitude || 0,
      speed: pos.coords.speed || 0,
      accuracy: pos.coords.accuracy || 0
    };
    emit({});
  }
}

// Pedometer disabled due to native bug
// function emitPedometer(data: PedometerMeasurement) {
//   cachedPedometer = { steps: data.numberOfSteps || 0, distance: data.distance || 0 };
//   emit({});
// }

export const SensorService = {
  async getDeviceInfo() {
    return await Device.getInfo();
  },

  async requestPermissions() {
    console.log('Requesting permissions...');
    try {
      const geoPerms = await Geolocation.requestPermissions();
      console.log('Geolocation permissions:', geoPerms.location);
    } catch (e: any) {
      console.log('Geolocation permission error:', e?.message);
    }
  },

  startAllSensors(_config: SensorConfig, listener: SensorListener) {
    console.log('Starting sensors...');
    sensorListener = listener;
    cachedMotion = null;
    cachedBarometer = null;
    cachedCompass = null;
    cachedGeolocation = null;
    cachedPedometer = null;
    cachedDevice = null;
    
    // Emit initial state immediately
    setTimeout(() => {
      listener({
        motion: null,
        barometer: null,
        compass: null,
        geolocation: null,
        pedometer: null,
        proximity: { enabled: true },
        device: null,
        camera: null
      });
    }, 50);
    
    // Get device info first
    Device.getInfo().then(info => {
      console.log('Device info:', info.model);
      cachedDevice = info;
      emit({});
    }).catch(e => console.log('Device error:', e));

    // Motion sensor - using setInterval as backup
    const motionInterval = setInterval(() => {
      // We'll rely on events, but emit cached data periodically
      if (cachedMotion) emit({});
    }, 200);
    
    Motion.addListener('accel', (event) => {
      console.log('Motion:', event.acceleration.x.toFixed(2), event.acceleration.y.toFixed(2), event.acceleration.z.toFixed(2));
      emitMotion(event);
    }).then(handle => {
      accelSubscription = { remove: () => { clearInterval(motionInterval); handle.remove(); }};
    }).catch(e => {
      console.log('Motion error:', e);
      clearInterval(motionInterval);
    });

    // Barometer
    CapacitorBarometer.startMeasurementUpdates().then(() => {
      console.log('Barometer started');
      CapacitorBarometer.addListener('measurement', emitBarometer).then(handle => {
        barometerSubscription = handle;
      });
    }).catch(e => console.log('Barometer error:', e));

    // Compass
    CapgoCompass.startListening().then(() => {
      console.log('Compass started');
      CapgoCompass.addListener('headingChange', emitCompass).then(handle => {
        compassSubscription = handle;
      });
    }).catch(e => console.log('Compass error:', e));

    // GPS - only start if location services are enabled
    Geolocation.getCurrentPosition().then((pos) => {
      console.log('GPS position:', pos.coords);
      emitGeolocation(pos);
    }).catch(e => console.log('GPS not available (enable location services):', e));

    Geolocation.watchPosition({ enableHighAccuracy: true }, (pos) => emitGeolocation(pos)).then(id => {
      geoWatchId = id;
    }).catch(() => {}); // Silently ignore - location may be off

    // Pedometer disabled due to native bug
    Device.getInfo().then(info => {
      cachedDevice = info;
      emit({});
    });
  },

  stopAllSensors() {
    console.log('Stopping sensors...');
    if (accelSubscription) { 
      accelSubscription.remove(); 
      accelSubscription = null; 
    }
    if (barometerSubscription) { barometerSubscription.remove(); barometerSubscription = null; }
    if (compassSubscription) { compassSubscription.remove(); compassSubscription = null; }
    if (geoWatchId) { Geolocation.clearWatch({ id: geoWatchId }).catch(() => {}); geoWatchId = null; }
    sensorListener = null;
    try { Motion.removeAllListeners(); } catch(e) {}
    CapacitorBarometer.stopMeasurementUpdates().catch(() => {});
    CapgoCompass.stopListening().catch(() => {});
    // CapacitorPedometer.stopMeasurementUpdates().catch(() => {});
  },

async takePhoto(): Promise<string | null> {
    try {
      const photo = await Camera.getPhoto({ quality: 50, resultType: CameraResultType.Uri });
      return photo.webPath || null;
    } catch (e: any) {
      console.log('Camera error:', e?.message || e);
      return null;
    }
  },

  async startRecording(): Promise<boolean> {
    try {
      const perms = await Microphone.requestPermissions();
      console.log('Mic permission:', perms);
      if (perms.microphone !== 'granted') return false;
      
      await Microphone.startRecording();
      console.log('Recording started');
      return true;
    } catch (e: any) {
      console.log('Recording error:', e?.message || e);
      return false;
    }
  },

  async stopRecording(): Promise<{ path?: string; duration: number } | null> {
    try {
      const file = await Microphone.stopRecording();
      console.log('Recording stopped, path:', file.path, 'duration:', file.duration);
      return { path: file.path, duration: file.duration };
    } catch (e: any) {
      console.log('Stop recording error:', e?.message || e);
      return null;
    }
  },

  getCapabilities() {
    return Promise.resolve({
      accelerometer: true,
      gyroscope: true,
      barometer: true,
      compass: true,
      geolocation: true,
      pedometer: true,
      proximity: true,
      device: true
    });
  },

  async checkBarometer() {
    return (await CapacitorBarometer.isAvailable()).isAvailable;
  },

  async checkCompass() {
    try {
      await CapgoCompass.getCurrentHeading();
      return true;
    } catch { return false; }
  },

  async checkGeolocation() {
    try {
      const perms = await Geolocation.checkPermissions();
      return perms.location === 'granted';
    } catch { return false; }
  },

  async checkPedometer() {
    return false; // Disabled due to native bug
  }
};