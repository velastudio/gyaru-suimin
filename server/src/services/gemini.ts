import { API_ERROR_CODES, ApiError } from '../errors/apiError.js';
import { logError } from '../logging/logger.js';
import { systemPrompt } from '../prompts/systemPrompt.js';

export const DEFAULT_GEMINI_MODEL = 'gemini-3-flash-preview';
export const GEMINI_TIMEOUT_MS = 8_000;

export type GeminiEnv = {
  GEMINI_API_KEY: string;
  GEMINI_MODEL?: string;
};

type GeminiResponse = {
  candidates?: Array<{
    content?: {
      parts?: Array<{
        text?: string | null;
      }>;
    };
  }>;
};

export class GeminiService {
  private readonly apiKey: string;
  private readonly model: string;

  constructor(env: GeminiEnv) {
    if (!env.GEMINI_API_KEY) {
      throw new Error('GEMINI_API_KEY is required');
    }

    this.apiKey = env.GEMINI_API_KEY;
    this.model = env.GEMINI_MODEL || DEFAULT_GEMINI_MODEL;
  }

  async generateResponse(message: string): Promise<string> {
    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': this.apiKey,
          },
          body: JSON.stringify({
            system_instruction: {
              parts: [{ text: systemPrompt }],
            },
            contents: [
              {
                parts: [{ text: message }],
              },
            ],
            generationConfig: {
              temperature: 0.8,
            },
          }),
          signal: AbortSignal.timeout(GEMINI_TIMEOUT_MS),
        },
      );

      if (!response.ok) {
        logError('gemini_request_failed', new Error(`status ${response.status}`), {
          model: this.model,
          reason: 'upstream_status',
          status: response.status,
        });

        throw new ApiError(
          502,
          API_ERROR_CODES.LLM_ERROR,
          'llm request failed',
        );
      }

      const payload = (await response.json()) as GeminiResponse;
      const text = payload.candidates?.[0]?.content?.parts?.[0]?.text?.trim();

      if (!text) {
        const error = new ApiError(
          502,
          API_ERROR_CODES.LLM_ERROR,
          'llm returned empty response',
        );

        logError('gemini_request_failed', error, {
          model: this.model,
          reason: 'empty_response',
        });

        throw error;
      }

      return text;
    } catch (error) {
      if (error instanceof ApiError) {
        throw error;
      }

      if (isTimeoutError(error)) {
        logError('gemini_request_failed', error, {
          model: this.model,
          reason: 'timeout',
        });

        throw new ApiError(
          502,
          API_ERROR_CODES.LLM_ERROR,
          'llm request timed out',
        );
      }

      logError('gemini_request_failed', error, {
        model: this.model,
        reason: 'unexpected_error',
      });

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
