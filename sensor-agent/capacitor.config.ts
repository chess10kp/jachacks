import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.sensoragent.app',
  appName: 'SensorAgent',
  webDir: 'dist',
  plugins: {
    Geolocation: {
      enableHighAccuracy: true
    },
    Barometer: {
      backgroundMetricHook: false
    }
  },
  android: {
    allowMixedContent: true
  }
};

export default config;