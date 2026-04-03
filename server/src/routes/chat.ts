import { Hono } from 'hono';
import { ZodError } from 'zod';

import { API_ERROR_CODES, ApiError } from '../errors/apiError.js';
import { logError, logInfo } from '../logging/logger.js';
import { validateChatRequest } from '../schemas/chat.js';

type ChatResponder = {
  generateResponse(message: string): Promise<string>;
};

export function createChatRoute(responder: ChatResponder) {
  const route = new Hono();

  route.post('/chat', async (context) => {
    let payload: unknown;

    try {
      payload = await context.req.json();
    } catch (error) {
      const apiError = new ApiError(
        400,
        API_ERROR_CODES.INVALID_REQUEST,
        'invalid json',
      );

      logError('chat_request_failed', error, {
        path: context.req.path,
        sessionId: undefined,
        status: apiError.status,
        code: apiError.code,
      });

      throw apiError;
    }

    try {
      const request = validateChatRequest(payload);
      const text = await responder.generateResponse(request.message);

      logInfo('chat_request_succeeded', {
        path: context.req.path,
        sessionId: request.sessionId,
      });

      return context.json({ text });
    } catch (error) {
      if (error instanceof ZodError) {
        const message = error.issues[0]?.message ?? 'invalid request';
        const sessionId =
          typeof payload === 'object' &&
          payload !== null &&
          'sessionId' in payload &&
          typeof payload.sessionId === 'string'
            ? payload.sessionId
            : undefined;
        const apiError = new ApiError(
          400,
          API_ERROR_CODES.INVALID_REQUEST,
          message,
        );

        logError('chat_request_failed', apiError, {
          path: context.req.path,
          sessionId,
          status: apiError.status,
          code: apiError.code,
        });

        throw apiError;
      }

      if (error instanceof ApiError) {
        const sessionId =
          typeof payload === 'object' &&
          payload !== null &&
          'sessionId' in payload &&
          typeof payload.sessionId === 'string'
            ? payload.sessionId
            : undefined;

        logError('chat_request_failed', error, {
          path: context.req.path,
          sessionId,
          status: error.status,
          code: error.code,
        });
      }

      throw error;
    }
  });

  return route;
}
