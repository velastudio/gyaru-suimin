import { GoogleGenAI } from '@google/genai';

import { systemPrompt } from '../prompts/systemPrompt.js';

export const DEFAULT_GEMINI_MODEL = 'gemini-3-flash-preview';

type GeminiEnv = {
  GEMINI_API_KEY?: string;
  GEMINI_MODEL?: string;
};

export class GeminiConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'GeminiConfigError';
  }
}

export function getGeminiConfig(env: GeminiEnv = process.env) {
  const apiKey = env.GEMINI_API_KEY;

  if (!apiKey) {
    throw new GeminiConfigError('GEMINI_API_KEY is required');
  }

  return {
    apiKey,
    model: env.GEMINI_MODEL || DEFAULT_GEMINI_MODEL,
  };
}

export class GeminiService {
  private readonly ai: GoogleGenAI;
  private readonly model: string;

  constructor(env: GeminiEnv = process.env) {
    const config = getGeminiConfig(env);

    this.ai = new GoogleGenAI({ apiKey: config.apiKey });
    this.model = config.model;
  }

  async generateResponse(message: string): Promise<string> {
    const response = await this.ai.models.generateContent({
      model: this.model,
      contents: message,
      config: {
        systemInstruction: systemPrompt,
      },
    });

    return response.text ?? '';
  }
}
