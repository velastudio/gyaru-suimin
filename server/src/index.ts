import { Hono } from 'hono';
import { handle } from 'hono/vercel';

import { API_ERROR_CODES, ApiError, jsonError } from './errors/apiError.js';
import { createChatRoute } from './routes/chat.js';
import { GeminiService } from './services/gemini.js';

const app = new Hono();
const geminiService = new GeminiService();

app.get('/health', (c) => {
  return c.json({ status: 'ok' });
});

app.route('/api', createChatRoute(geminiService));

app.onError((error, context) => {
  if (error instanceof ApiError) {
    return jsonError(context, error);
  }

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
export default handle(app);
