import { Motion, type AccelListenerEvent } from '@capacitor/motion';
import { CapacitorBarometer, type Measurement } from '@capgo/capacitor-barometer';
import { CapgoCompass, type HeadingChangeEvent } from '@capgo/capacitor-compass';
import { Device, type DeviceInfo } from '@capacitor/device';
import { Geolocation, type Position } from '@capacitor/geolocation';
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
let motionSub: { remove: () => void } | null = null;
let baroSub: { remove: () => void } | null = null;
let compassSub: { remove: () => void } | null = null;
let geoWatchId: string | null = null;
let isRunning = false;

let cachedMotion: MotionData | null = null;
let cachedBarometer: { pressure: number; relativeAltitude: number } | null = null;
let cachedCompass: { heading: number } | null = null;
let cachedGeo: { lat: number; lng: number; alt: number; speed: number; accuracy: number } | null = null;
let cachedDevice: DeviceInfo | null = null;

function emitAll() {
  if (!sensorListener || !isRunning) return;
  sensorListener({
    motion: cachedMotion,
    barometer: cachedBarometer,
    compass: cachedCompass,
    geolocation: cachedGeo,
    pedometer: null,
    proximity: { enabled: true },
    device: cachedDevice,
    camera: null
  });
}

export const SensorService = {
  async getDeviceInfo() {
    return await Device.getInfo();
  },

  async requestPermissions() {
    try { await Geolocation.requestPermissions(); } catch {}
  },

  startAllSensors(_config: SensorConfig, listener: SensorListener) {
    console.log('START SENSORS');
    isRunning = true;
    sensorListener = listener;
    cachedMotion = null;
    cachedBarometer = null;
    cachedCompass = null;
    cachedGeo = null;
    cachedDevice = null;
    
    // Initial empty state
    setTimeout(() => listener({
      motion: null, barometer: null, compass: null, geolocation: null,
      pedometer: null, proximity: { enabled: true }, device: null, camera: null
    }), 50);

    // Device info
    Device.getInfo().then(info => {
      cachedDevice = info;
      emitAll();
    }).catch(() => {});

    // Motion sensor - simplified
    Motion.addListener('accel', (e: AccelListenerEvent) => {
      console.log('Motion event:', e.acceleration.x, e.acceleration.y, e.acceleration.z);
      cachedMotion = {
        acceleration: { x: e.acceleration.x, y: e.acceleration.y, z: e.acceleration.z },
        rotationRate: { alpha: e.rotationRate.alpha, beta: e.rotationRate.beta, gamma: e.rotationRate.gamma },
        timestamp: Date.now()
      };
      emitAll();
    }).then(h => { 
      console.log('Motion listener registered');
      motionSub = h; 
    }).catch(e => console.log('Motion fail:', e));

    // Barometer
    CapacitorBarometer.removeAllListeners().then(() => {
      return CapacitorBarometer.startMeasurementUpdates();
    }).then(() => {
      return CapacitorBarometer.addListener('measurement', (e: Measurement) => {
        cachedBarometer = { pressure: e.pressure, relativeAltitude: e.relativeAltitude };
        emitAll();
      });
    }).then(h => { baroSub = h; }).catch(() => console.log('Barometer fail'));

    // Compass
    CapgoCompass.removeAllListeners().then(() => {
      return CapgoCompass.startListening();
    }).then(() => {
      return CapgoCompass.addListener('headingChange', (e: HeadingChangeEvent) => {
        cachedCompass = { heading: e.value };
        emitAll();
      });
    }).then(h => { compassSub = h; }).catch(() => console.log('Compass fail'));

    // GPS
    Geolocation.getCurrentPosition().then((p: Position) => {
      if (p.coords) {
        cachedGeo = { lat: p.coords.latitude, lng: p.coords.longitude, alt: p.coords.altitude || 0, speed: p.coords.speed || 0, accuracy: p.coords.accuracy || 0 };
        emitAll();
      }
    }).catch(() => {});

    Geolocation.watchPosition({ enableHighAccuracy: true }, (p: Position | null) => {
      if (p && p.coords) {
        cachedGeo = { lat: p.coords.latitude, lng: p.coords.longitude, alt: p.coords.altitude || 0, speed: p.coords.speed || 0, accuracy: p.coords.accuracy || 0 };
        emitAll();
      }
    }).then(id => { geoWatchId = id; }).catch(() => {});
  },

  stopAllSensors() {
    console.log('STOP SENSORS');
    isRunning = false;
    sensorListener = null;
    cachedMotion = null;
    cachedBarometer = null;
    cachedCompass = null;
    cachedGeo = null;
    
    if (motionSub) { motionSub.remove(); motionSub = null; }
    if (baroSub) { baroSub.remove(); baroSub = null; }
    if (compassSub) { compassSub.remove(); compassSub = null; }
    if (geoWatchId) { Geolocation.clearWatch({ id: geoWatchId }); geoWatchId = null; }
  },

  async takePhoto(): Promise<string | null> {
    try {
      const photo = await Camera.getPhoto({ quality: 50, resultType: CameraResultType.Uri });
      return photo.webPath || null;
    } catch { return null; }
  },

  async startRecording(): Promise<boolean> {
    try {
      const perms = await Microphone.requestPermissions();
      if (perms.microphone !== 'granted') return false;
      await Microphone.startRecording();
      return true;
    } catch { return false; }
  },

  async stopRecording(): Promise<{ path?: string; duration: number } | null> {
    try {
      const file = await Microphone.stopRecording();
      return { path: file.path, duration: file.duration };
    } catch { return null; }
  },

  getCapabilities() {
    return Promise.resolve({
      accelerometer: true, gyroscope: true, barometer: true,
      compass: true, geolocation: true, pedometer: false, proximity: true, device: true
    });
  },

  async checkBarometer() { try { return (await CapacitorBarometer.isAvailable()).isAvailable; } catch { return false; } },
  async checkCompass() { try { await CapgoCompass.getCurrentHeading(); return true; } catch { return false; } },
  async checkGeolocation() { try { const p = await Geolocation.checkPermissions(); return p.location === 'granted'; } catch { return false; } },
  async checkPedometer() { return false; }
};