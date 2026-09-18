import { registerPlugin } from '@capacitor/core';
import type { VistaStreamHybridPlayerPlugin } from './definitions.js';

export const VistaStreamHybridPlayer = registerPlugin<VistaStreamHybridPlayerPlugin>('VistaStreamHybridPlayer');
export * from './definitions.js';
