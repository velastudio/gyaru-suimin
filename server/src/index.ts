import { Hono } from 'hono';

import { API_ERROR_CODES, ApiError, jsonError } from './errors/apiError.js';
import { logError } from './logging/logger.js';
import { createChatRoute } from './routes/chat.js';
import { GeminiService } from './services/gemini.js';

type Bindings = {
  GEMINI_API_KEY: string;
  GEMINI_MODEL?: string;
};

const app = new Hono<{ Bindings: Bindings }>();

app.get('/health', (c) => {
  return c.json({ status: 'ok' });
});

app.route(
  '/api',
  createChatRoute((env) => new GeminiService(env)),
);

app.onError((error, context) => {
  if (error instanceof ApiError) {
    return jsonError(context, error);
  }

  logError('request_unhandled_error', error, {
    method: context.req.method,
    path: context.req.path,
  });

  return jsonError(
    context,
    new ApiError(
      500,
      API_ERROR_CODES.INTERNAL_SERVER_ERROR,
      'internal server error',
    ),
  );
});

export { app };
export default app;
