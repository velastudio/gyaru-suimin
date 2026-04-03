import { GoogleGenAI } from '@google/genai';

import { API_ERROR_CODES, ApiError } from '../errors/apiError.js';
import { systemPrompt } from '../prompts/systemPrompt.js';

export const DEFAULT_GEMINI_MODEL = 'gemini-3-flash-preview';
export const GEMINI_TIMEOUT_MS = 8_000;

type GeminiEnv = {
  GEMINI_API_KEY?: string;
  GEMINI_MODEL?: string;
};

type GenerateContentResult = {
  text?: string | null;
};

type GeminiClient = {
  models: {
    generateContent: (request: {
      model: string;
      contents: string;
      config: {
        systemInstruction: string;
        httpOptions: {
          timeout: number;
        };
      };
    }) => Promise<GenerateContentResult>;
  };
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
  private readonly ai: GeminiClient;
  private readonly model: string;

  constructor(
    env: GeminiEnv = process.env,
    ai?: GeminiClient,
  ) {
    const config = getGeminiConfig(env);

    this.ai = ai ?? new GoogleGenAI({ apiKey: config.apiKey });
    this.model = config.model;
  }

  async generateResponse(message: string): Promise<string> {
    try {
      const response = await this.ai.models.generateContent({
        model: this.model,
        contents: message,
        config: {
          systemInstruction: systemPrompt,
          httpOptions: {
            timeout: GEMINI_TIMEOUT_MS,
          },
        },
      });

      const text = response.text?.trim();

      if (!text) {
        throw new ApiError(
          502,
          API_ERROR_CODES.LLM_ERROR,
          'llm returned empty response',
        );
      }

      return text;
    } catch (error) {
      if (error instanceof ApiError) {
        throw error;
      }

      if (isTimeoutError(error)) {
        throw new ApiError(
          502,
          API_ERROR_CODES.LLM_ERROR,
          'llm request timed out',
        );
      }

      throw new ApiError(
        502,
        API_ERROR_CODES.LLM_ERROR,
        'llm request failed',
      );
    }
  }
}

function isTimeoutError(error: unknown): boolean {
  if (!(error instanceof Error)) {
    return false;
  }

  const message = error.message.toLowerCase();

  return error.name === 'AbortError' || message.includes('timeout');
}
