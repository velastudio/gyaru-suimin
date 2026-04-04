import { Hono } from 'hono';

import { API_ERROR_CODES, ApiError, jsonError } from './errors/apiError.js';
import { logError, logInfo } from './logging/logger.js';
import { createChatRoute } from './routes/chat.js';
import { GeminiService } from './services/gemini.js';

type Bindings = {
  GEMINI_API_KEY: string;
  GEMINI_MODEL?: string;
  RATE_LIMITER: RateLimit;
};

const app = new Hono<{ Bindings: Bindings }>();

app.get('/health', (c) => {
  return c.json({ status: 'ok' });
});

app.use('/api/chat', async (context, next) => {
  if (context.req.method !== 'POST') {
    await next();
    return;
  }

  const limiter = context.env.RATE_LIMITER;

  if (typeof limiter?.limit !== 'function') {
    await next();
    return;
  }

  const key = context.req.header('CF-Connecting-IP') ?? 'unknown';
  const result = await limiter.limit({ key });

  if (!result.success) {
    logInfo('chat_request_rate_limited', {
      path: context.req.path,
      key,
    });

    throw new ApiError(
      429,
      API_ERROR_CODES.RATE_LIMITED,
      'rate limit exceeded',
    );
  }

  await next();
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
