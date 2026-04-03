import { Hono } from 'hono';
import { ZodError } from 'zod';

import { API_ERROR_CODES, ApiError } from '../errors/apiError.js';
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
    } catch {
      throw new ApiError(
        400,
        API_ERROR_CODES.INVALID_REQUEST,
        'invalid json',
      );
    }

    try {
      const request = validateChatRequest(payload);
      const text = await responder.generateResponse(request.message);

      return context.json({ text });
    } catch (error) {
      if (error instanceof ZodError) {
        const message = error.issues[0]?.message ?? 'invalid request';

        throw new ApiError(
          400,
          API_ERROR_CODES.INVALID_REQUEST,
          message,
        );
      }

      throw error;
    }
  });

  return route;
}
