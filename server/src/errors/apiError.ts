import type { Context } from 'hono';

export const API_ERROR_CODES = {
  INVALID_REQUEST: 'INVALID_REQUEST',
  INTERNAL_SERVER_ERROR: 'INTERNAL_SERVER_ERROR',
  LLM_ERROR: 'LLM_ERROR',
} as const;

export type ApiErrorCode =
  (typeof API_ERROR_CODES)[keyof typeof API_ERROR_CODES];

export class ApiError extends Error {
  readonly status: 400 | 500 | 502;
  readonly code: ApiErrorCode;

  constructor(status: 400 | 500 | 502, code: ApiErrorCode, message: string) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
  }
}

export function jsonError(
  context: Context,
  error: ApiError,
): Response | Promise<Response> {
  return context.json(
    {
      error: {
        code: error.code,
        message: error.message,
      },
    },
    error.status,
  );
}
