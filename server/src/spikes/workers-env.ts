import { Hono } from 'hono';

type WorkersEnv = {
  GEMINI_API_KEY?: string;
};

const app = new Hono<{ Bindings: WorkersEnv }>();

app.get('/env-check', (c) => {
  return c.json({
    hasGeminiApiKey: Boolean(c.env.GEMINI_API_KEY),
  });
});

export default app;
