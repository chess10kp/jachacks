import type { MotionData } from './SensorService';

export interface AgentAction {
  type: 'notify' | 'log' | 'trigger';
  message: string;
  priority: number;
}

export interface AgentConfig {
  apiEndpoint: string;
  motionThreshold: number;
  decisionInterval: number;
  autoAct: boolean;
}

type ActionHandler = (action: AgentAction) => void;

export interface AgentState {
  isRunning: boolean;
  decisions: AgentAction[];
  lastMotion: MotionData | null;
}

const defaultConfig: AgentConfig = {
  apiEndpoint: 'https://api.openai.com/v1/chat/completions',
  motionThreshold: 2.0,
  decisionInterval: 5000,
  autoAct: true
};

let config: AgentConfig = { ...defaultConfig };
let actionHandler: ActionHandler | null = null;
let state: AgentState = {
  isRunning: false,
  decisions: [],
  lastMotion: null
};
let decisionLoop: ReturnType<typeof setInterval> | null = null;

function calculateMotionIntensity(data: MotionData): number {
  const { x, y, z } = data.acceleration;
  return Math.sqrt(x * x + y * y + z * z);
}

function generateDecision(motionData: MotionData): AgentAction {
  const intensity = calculateMotionIntensity(motionData);
  const isHighMotion = intensity > config.motionThreshold;
  
  if (isHighMotion) {
    return {
      type: config.autoAct ? 'trigger' : 'notify',
      message: `High motion detected: intensity ${intensity.toFixed(2)}`,
      priority: intensity > 10 ? 2 : 1
    };
  }
  
  return {
    type: 'log',
    message: `Normal motion: intensity ${intensity.toFixed(2)}`,
    priority: 0
  };
}

async function queryAI(motionData: MotionData): Promise<AgentAction> {
  const intensity = calculateMotionIntensity(motionData);
  const state = intensity > config.motionThreshold ? 'active' : 'idle';
  
  return {
    type: config.autoAct ? 'trigger' : 'notify',
    message: `Motion state: ${state}, intensity: ${intensity.toFixed(1)}`,
    priority: Math.floor(intensity / 5)
  };
}

export const AIAgent = {
  configure(newConfig: Partial<AgentConfig>) {
    config = { ...config, ...newConfig };
  },

  getConfig(): AgentConfig {
    return { ...config };
  },

  getState(): AgentState {
    return { ...state };
  },

  start(handler: ActionHandler) {
    if (state.isRunning) return;
    
    actionHandler = handler;
    state.isRunning = true;
    
    decisionLoop = setInterval(async () => {
      if (!state.lastMotion) return;
      
      const decision = await queryAI(state.lastMotion);
      state.decisions.push(decision);
      
      if (actionHandler && decision.priority > 0) {
        actionHandler(decision);
      }
    }, config.decisionInterval);
  },

  stop() {
    if (decisionLoop) {
      clearInterval(decisionLoop);
      decisionLoop = null;
    }
    state.isRunning = false;
    actionHandler = null;
  },

  processSensorData(motionData: MotionData) {
    state.lastMotion = motionData;
    
    const localDecision = generateDecision(motionData);
    if (localDecision.priority > 0 && actionHandler) {
      actionHandler(localDecision);
    }
  },

  clearDecisions() {
    state.decisions = [];
  }
};